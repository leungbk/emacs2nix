{-

emacs2nix - Generate Nix expressions for Emacs packages
Copyright (C) 2016 Thomas Tuegel

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

-}

module Main where

import Control.Concurrent ( getNumCapabilities, setNumCapabilities )
import Control.Monad ( join )
import Data.HashSet ( HashSet )
import qualified Data.HashSet as HashSet
import Data.Monoid ( (<>) )
import Data.Text ( Text )
import qualified Data.Text as T
import Options.Applicative
import System.Environment ( setEnv, unsetEnv )

import qualified Distribution.Emacs.Name as Emacs
import Distribution.Melpa
import qualified Distribution.Nix.Name as Nix.Name

main :: IO ()
main = join (execParser (info (helper <*> parser) desc))
  where
    desc = fullDesc <> progDesc "Generate Nix expressions from MELPA recipes"

parser :: Parser (IO ())
parser =
  melpa2nix
  <$> (threads <|> pure 0)
  <*> melpa
  <*> output
  <*> names
  <*> packages
  where
    threads = option auto (long "threads" <> short 't' <> metavar "N"
                          <> help "use N threads; default is number of CPUs")
    melpa = strOption (long "melpa" <> metavar "DIR"
                        <> help "path to MELPA repository")
    output = strOption (long "output" <> short 'o' <> metavar "FILE"
                        <> help "dump MELPA data to FILE")
    names = strOption (long "names" <> metavar "FILE"
                       <> help "map Emacs names to Nix names using FILE")
    packages = HashSet.fromList . map T.pack
                <$> many (strArgument
                          (metavar "PACKAGE" <> help "only work on PACKAGE"))

melpa2nix
  :: Int  -- ^ number of threads to use
  -> FilePath  -- ^ path to MELPA repository
  -> FilePath  -- ^ dump MELPA recipes here
  -> FilePath  -- ^ map of Emacs names to Nix names
  -> HashSet Text  -- ^ selected packages
  -> IO ()
melpa2nix nthreads melpaDir melpaOut namesFile packages =
  do
    -- set number of threads before beginning
    if nthreads > 0
      then setNumCapabilities nthreads
      else getNumCapabilities >>= setNumCapabilities . (* 4)
    -- Force our TZ to match the melpa build machines
    setEnv "TZ" "PST8PDT"
    -- Any operation requiring a password should fail
    unsetEnv "SSH_ASKPASS"

    names <- Nix.Name.readNames namesFile
    selectedNames <- getSelectedNames names (HashSet.map Emacs.Name packages)

    updateMelpa melpaDir melpaOut names selectedNames
