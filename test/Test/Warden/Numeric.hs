{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell   #-}

module Test.Warden.Numeric where

import           Disorder.Core.Property

import           P

import           System.IO

import           Test.QuickCheck
import           Test.QuickCheck.Instances ()

import           Test.Warden.Arbitrary ()

import           Warden.Data
import           Warden.Numeric

prop_updateminimum_positive :: Minimum -> Property
prop_updateminimum_positive mn@(Minimum Nothing) = forAll (arbitrary :: Gen Double) $ \x ->
  (updateMinimum mn x) === (Minimum (Just x))
prop_updateminimum_positive mn@(Minimum (Just c)) = forAll ((arbitrary :: Gen Double) `suchThat` (< c)) $ \x ->
  (updateMinimum mn x) === (Minimum (Just x))

prop_updatemaximum_positive :: Maximum -> Property
prop_updatemaximum_positive mn@(Maximum Nothing) = forAll (arbitrary :: Gen Double) $ \x ->
  (updateMaximum mn x) === (Maximum (Just x))
prop_updatemaximum_positive mx@(Maximum (Just c)) = forAll ((arbitrary :: Gen Double) `suchThat` (> c)) $ \x ->
  (updateMaximum mx x) === (Maximum (Just x))

prop_updateminimum_negative :: Property
prop_updateminimum_negative =
  forAll (arbitrary :: Gen Double) $ \c ->
    forAll ((arbitrary :: Gen Double) `suchThat` (>= c)) $ \x ->
      let mn = Minimum (Just c)
      in (updateMinimum mn x) === mn

prop_updatemaximum_negative :: Property
prop_updatemaximum_negative =
  forAll (arbitrary :: Gen Double) $ \c ->
    forAll ((arbitrary :: Gen Double) `suchThat` (<= c)) $ \x ->
      let mx = Maximum (Just c)
      in (updateMaximum mx x) === mx

prop_updatemean :: Int -> Property
prop_updatemean n = forAll (vectorOf n (arbitrary :: Gen Double)) $ \xs ->
  let soq = finalizeMean $ foldl updateMean MeanInitial xs
      qos = if n > 0
              then Just . Mean $ ((sum xs) / (fromIntegral n))
              else Nothing
  in soq ~~~ qos

return []
tests :: IO Bool
tests = $quickCheckAll
