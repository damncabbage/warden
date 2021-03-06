{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE LambdaCase #-}

module Test.Warden.Numeric where

import           Data.List (take)
import qualified Data.Vector.Unboxed as VU

import           Disorder.Core.Property ((~~~), (###))
import           Disorder.Core.UniquePair (UniquePair)

import           P

import           System.IO

import           Test.QuickCheck
import           Test.QuickCheck.Instances ()

import           Test.Warden
import           Test.Warden.Arbitrary

import           Warden.Data
import           Warden.Numeric

textbookMean :: (Num a, Fractional a) => [a] -> a
textbookMean xs =
  (sum xs) / (fromIntegral $ length xs)

textbookVariance :: (Num a, Fractional a) => a -> [a] -> a
textbookVariance mu xs =
  (foldr (\v acc -> acc + ((v - mu) ^ two)) 0.0 xs) / fromIntegral (length xs)
  where
    two :: Int
    two = 2

prop_updateMinimum_positive :: Minimum -> Property
prop_updateMinimum_positive NoMinimum = forAll (arbitrary :: Gen Double) $ \x ->
  (updateMinimum NoMinimum x) === (Minimum x)
prop_updateMinimum_positive mn@(Minimum c) = forAll ((arbitrary :: Gen Double) `suchThat` (< c)) $ \x ->
  (updateMinimum mn x) === (Minimum x)

prop_updateMaximum_positive :: Maximum -> Property
prop_updateMaximum_positive NoMaximum = forAll (arbitrary :: Gen Double) $ \x ->
  (updateMaximum NoMaximum x) === (Maximum x)
prop_updateMaximum_positive mx@(Maximum c) = forAll ((arbitrary :: Gen Double) `suchThat` (> c)) $ \x ->
  (updateMaximum mx x) === (Maximum x)

prop_updateMinimum_negative :: Property
prop_updateMinimum_negative =
  forAll (arbitrary :: Gen Double) $ \c ->
    forAll ((arbitrary :: Gen Double) `suchThat` (>= c)) $ \x ->
      let mn = Minimum c
      in (updateMinimum mn x) === mn

prop_updateMinimum_associative :: Int -> Property
prop_updateMinimum_associative n = forAll (vectorOf n (arbitrary :: Gen Double)) $ \xs ->
  associativity updateMinimum NoMinimum xs $ \case
    NoMinimum -> 0.0
    Minimum v -> v

prop_updateMaximum_negative :: Property
prop_updateMaximum_negative =
  forAll (arbitrary :: Gen Double) $ \c ->
    forAll ((arbitrary :: Gen Double) `suchThat` (<= c)) $ \x ->
      let mx = Maximum c
      in (updateMaximum mx x) === mx

prop_updateMaximum_associative :: Int -> Property
prop_updateMaximum_associative n = forAll (vectorOf n (arbitrary :: Gen Double)) $ \xs ->
  associativity updateMaximum NoMaximum xs $ \case
    NoMaximum -> 0.0
    Maximum v -> v

prop_updateMeanDev :: NPlus -> Property
prop_updateMeanDev (NPlus n) = forAll (vectorOf n (arbitrary :: Gen Double)) $ \xs ->
  let mda = foldl updateMeanDev MeanDevInitial xs
      nsMeanDev = finalizeMeanDev mda
      mu = textbookMean xs
      var = textbookVariance mu xs
      sd = StdDev $ sqrt var
      uMeanDev = (Mean mu, sd) in
  (nsMeanDev, Just (n+1)) ~~~ (uMeanDev, meanDevKAcc mda)
  where
    meanDevKAcc MeanDevInitial = Nothing
    meanDevKAcc (MeanDevAcc _ _ (KAcc c)) = Just c

prop_updateMeanDev_associative :: [Double] -> Property
prop_updateMeanDev_associative xs =
  associativity updateMeanDev MeanDevInitial xs finalizeMeanDev

prop_updateNumericState_associative :: [Double] -> Property
prop_updateNumericState_associative xs =
  associativity updateNumericState initialNumericState xs id

prop_combineNumericState_commutative :: UniquePair NumericState -> Property
prop_combineNumericState_commutative = commutativity combineNumericState

meanDevAccEq :: MeanDevAcc -> MeanDevAcc -> Property
meanDevAccEq (MeanDevAcc m1 (MStdDevAcc d1) k1) (MeanDevAcc m2 (MStdDevAcc d2) k2) = conjoin [
    m1 ### m2
  , d1 ### d2
  , k1 === k2
  ]
meanDevAccEq (MeanDevAcc m1 NoStdDevAcc k1) (MeanDevAcc m2 NoStdDevAcc k2) = conjoin [
    m1 ### m2
  , k1 === k2
  ]
meanDevAccEq x y = x ~~~ y

prop_combineMeanDevAcc :: Property
prop_combineMeanDevAcc = forAll smallPositiveEven $ \n -> forAll (vectorOf n (arbitrary :: Gen Double)) $ \xs ->
  let m = n `div` 2
      mda = foldl updateMeanDev MeanDevInitial xs
      xs1 = take m xs
      xs2 = drop m xs
      mda1 = foldl updateMeanDev MeanDevInitial xs1
      mda2 = foldl updateMeanDev MeanDevInitial xs2
      mda' = combineMeanDevAcc mda1 mda2 in
  mda `meanDevAccEq` mda'

prop_tripping_StdDevAcc :: KAcc -> StdDevAcc -> Property
prop_tripping_StdDevAcc ka sda =
  let sda' = stdDevAccFromVariance ka $ varianceFromStdDevAcc ka sda in
  sda ~~~ sda'

prop_combineMeanDevAcc_commutative :: UniquePair MeanDevAcc -> Property
prop_combineMeanDevAcc_commutative =
  commutativity combineMeanDevAcc

prop_unsafeMedian_odd :: Int -> Property
prop_unsafeMedian_odd md = forAll (choose (0, 100)) $ \k -> forAll ((,) <$> vectorOf k (choose (md, maxBound)) <*> vectorOf k (choose (minBound, md))) $ \(xs, ys) ->
  forAll (shuffle (xs <> [md] <> ys)) $ \l ->
    let v = VU.fromList $ fromIntegral <$> l
        md' = unsafeMedian v in
  fromIntegral md === md'

prop_unsafeMedian_even :: Int -> Int -> Property
prop_unsafeMedian_even mda mdb =
  let md1 = min mda mdb
      md2 = max mda mdb in
  forAll (choose (0, 100)) $ \k ->
  forAll ((,) <$> vectorOf k (choose (md2, maxBound)) <*> vectorOf k (choose (minBound, md1))) $ \(xs, ys) ->
  forAll (shuffle (xs <> [md1, md2] <> ys)) $ \l ->
    let v = VU.fromList $ fromIntegral <$> l
        md' = unsafeMedian v
        md = ((fromIntegral md1) + (fromIntegral md2)) / 2 in
  md === md'


return []
tests :: IO Bool
tests = $forAllProperties $ quickCheckWithResult (stdArgs { maxSuccess = 1000 } )
