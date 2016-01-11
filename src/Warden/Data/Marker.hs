{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Warden.Data.Marker (
    FileMarker(..)
  , ViewMarker(..)
  , ViewMetadata(..)
  , filePathChar
  , fileToMarker
  , markerToFile
  , markerToView
  , viewToMarker
  ) where

import           Data.Attoparsec.Text (IResult(..), Parser, parse)
import           Data.Attoparsec.Text (string, satisfy, manyTill)
import           Data.Char (ord)
import qualified Data.Text as T

import           Delorean.Local.DateTime (DateTime)

import           System.FilePath ((</>), takeFileName, replaceFileName)
import           System.FilePath (takeDirectory)
import           System.IO (FilePath)

import           P

import           Warden.Data.Check
import           Warden.Data.SeparatedValues
import           Warden.Data.View

data FileMarker =
  FileMarker {
    fmViewFile :: ViewFile
  , fmTimestamp :: DateTime
  , fmCheckResults :: [CheckResult]
  } deriving (Eq, Show)

markerSuffix :: FilePath
markerSuffix = ".warden"

fileToMarker :: ViewFile -> FilePath
fileToMarker (ViewFile vf) =
  let fileName   = takeFileName vf
      markerFile = "_" <> fileName <> markerSuffix in
  replaceFileName vf markerFile

markerToFile :: View -> FilePath -> Maybe ViewFile
markerToFile v fp
  | not (isViewFile v fp) = Nothing
  | otherwise             = do
      fn <- finalize . parse fileMarker . T.pack $ takeFileName fp
      pure . ViewFile $ replaceFileName fp fn
  where
    fileMarker :: Parser FilePath
    fileMarker =
      string "_" *> manyTill filePathChar (string (T.pack markerSuffix))

    finalize (Partial c)  = finalize $ c ""
    finalize (Done "" "") = Nothing
    finalize (Done "" r)  = Just r
    finalize _            = Nothing

viewToMarker :: View -> FilePath
viewToMarker (View v) =
  v </> ("_view" <> markerSuffix)

markerToView :: FilePath -> Maybe View
markerToView fp =
  let v = takeDirectory fp
      fn = takeFileName fp in
  case fn of
    "_view.warden" -> Just $ View v
    _              -> Nothing

filePathChar :: Parser Char
filePathChar = satisfy (not . bad)
  where
    bad c = or [
        -- This fails some filenames which POSIX might call valid; this is
        -- by design.
        (ord c) < 32
      , c == '/'
      ]

data ViewMarker =
  ViewMarker {
    vmView :: View
  , vmTimestamp :: DateTime
  , vmCheckResults :: [CheckResult]
  , vmMetadata :: ViewMetadata
  } deriving (Eq, Show)

data ViewMetadata =
  ViewMetadata {
    viewCounts :: SVParseState
  } deriving (Eq, Show)