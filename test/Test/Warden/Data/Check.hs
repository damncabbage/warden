{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}

module Test.Warden.Data.Check where

import           Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NE

import           P

import           System.IO (IO)

import           Test.QuickCheck
import           Test.Warden.Arbitrary

import           Warden.Data

prop_checkStatusFailed :: NonEmpty Failure -> Property
prop_checkStatusFailed fs =
  (checkStatusFailed $ CheckFailed fs, checkStatusFailed CheckPassed) === (True, False)

prop_resolveCheckStatus_pass :: NonEmpty CheckStatusPassed -> Property
prop_resolveCheckStatus_pass ss =
  let s' = resolveCheckStatus $ unCheckStatusPassed <$> ss in
  (not $ checkStatusFailed s') === True

prop_resolveCheckStatus_fail :: NonEmpty CheckStatusFailed -> Property
prop_resolveCheckStatus_fail ss =
  let ss' = unCheckStatusFailed <$> ss
      s'  = resolveCheckStatus ss' in
  (checkStatusFailed s', all (flip elem $ failures s') (concatMap failures $ NE.toList ss')) === (True, True)
  where
    failures CheckPassed = []
    failures (CheckFailed fs) = NE.toList fs

return []
tests :: IO Bool
tests = $quickCheckAll
