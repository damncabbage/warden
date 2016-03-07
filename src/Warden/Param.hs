{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Warden.Param(
    buildWardenParams
  ) where

import           Control.Concurrent (getNumCapabilities)

import           Data.UUID.V4 (nextRandom)

import           P

import           System.IO (IO)

import           Warden.Data.Param

buildWardenParams :: WardenVersion -> IO WardenParams
buildWardenParams v = WardenParams <$> getNumCPUs
                                   <*> pure v
                                   <*> genRunId

genRunId :: IO RunId
genRunId = RunId <$> nextRandom

getNumCPUs :: IO NumCPUs
getNumCPUs = NumCPUs <$> getNumCapabilities
