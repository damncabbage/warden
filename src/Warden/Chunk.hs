{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Warden.Chunk(
  chunk
) where

import           Data.ByteString.Char8 (hGet)
import           Data.List.NonEmpty (NonEmpty(..), zip)
import qualified Data.List.NonEmpty as NE

import           P

import           System.IO (IO, IOMode (..), SeekMode (..), FilePath, Handle)
import           System.IO (withFile, hFileSize, hTell, hIsEOF, hSeek)

import           Warden.Data.Chunk

chunk :: ChunkCount -> FilePath -> IO (NonEmpty Chunk)
chunk n fp =
  withFile fp ReadMode $ \h -> do
    size <- hFileSize h
    if size < 1024 * 1024
      then pure $! (Chunk (ChunkOffset 0) (ChunkSize size)) :| []
      else chunk' h size n

chunk' :: Handle -> Integer -> ChunkCount -> IO (NonEmpty Chunk)
chunk' h size count' = do
  offsets <- calculateOffsets h size count'
  let chunks = zip offsets $ (NE.fromList $ (fmap unChunkOffset . drop 1 $ NE.toList offsets) <> [size])
  pure $ (\(o, n) -> Chunk o (ChunkSize $ n - (unChunkOffset o))) <$> chunks

calculateOffsets :: Handle -> Integer -> ChunkCount -> IO (NonEmpty ChunkOffset)
calculateOffsets h size (ChunkCount count') = do
  let rough = floor (fromIntegral size / fromIntegral count' :: Double)
  rest <- forM [1 .. (count' - 1)] $ \n -> do
    let start = rough * toInteger n
    hSeek h AbsoluteSeek start
    offset <- nextLine h >> hTell h
    pure $! ChunkOffset offset
  pure $! (ChunkOffset 0 :| rest)

nextLine :: Handle -> IO ()
nextLine h = do
  unlessM (hIsEOF h) $ do
    -- FIXME: this will probably break with some weird unicode characters
    c <- hGet h 1
    unless (c == "\n") $
      nextLine h
