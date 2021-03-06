{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

module Test.IO.Warden.View.Unit where

import           Control.Monad.Trans.Resource (runResourceT)

import           Data.List (sort)
import           Data.List.NonEmpty (NonEmpty(..))

import           Disorder.Core.IO (testIO)

import           P

import           System.IO

import           Test.QuickCheck
import           Test.IO.Warden

import           Warden.Data
import           Warden.Error
import           Warden.View

import           X.Control.Monad.Trans.Either (runEitherT, mapEitherT)

prop_traverseDirectory :: Property
prop_traverseDirectory = testWarden $ do
  fs <- directoryFiles <$> traverseDirectory NoIncludeDotFiles (MaxDepth 4) [] "test/data/view/view"
  pure $ (sort fs === sort expected)
  where
    expected = [
         "test/data/view/view/year=2014/month=09/day=23/bar-3"
       , "test/data/view/view/year=2014/month=09/day=01/bar-4"
       , "test/data/view/view/year=2015/month=01/bad"
       , "test/data/view/view/year=2015/month=01/day=31/bar-7"
       ]

prop_traverseView' :: Property
prop_traverseView' = testWarden $ do
  (bads, goods) <- traverseView' NoIncludeDotFiles (View "test/data/view/view")
  pure $ (sort (fmap viewFilePath goods), sort bads) === bimap sort sort expected
  where
    expected = (
      [
        "test/data/view/view/year=2014/month=09/day=23/bar-3"
      , "test/data/view/view/year=2014/month=09/day=01/bar-4"
      , "test/data/view/view/year=2015/month=01/day=31/bar-7"
      ],
      [
        NonViewFile {unNonViewFile = "test/data/view/view/year=2015/month=01/bad"}
      ])

prop_traverseView_empty :: Property
prop_traverseView_empty = testIO $ do
  r <- runEitherT . mapEitherT runResourceT $
    traverseView NoIncludeDotFiles (View "test/data/view/empty-view")
  pure $ r === (Left $ WardenTraversalError EmptyView)

prop_traverseView_bad :: Property
prop_traverseView_bad = testIO $ do
  r <- runEitherT . mapEitherT runResourceT $
    traverseView NoIncludeDotFiles (View "test/data/view/view")
  pure $ r === (Left . WardenTraversalError $ NonViewFiles [NonViewFile {unNonViewFile = "test/data/view/view/year=2015/month=01/bad"}])

prop_traverseView_deep :: Property
prop_traverseView_deep = testIO $ do
  r <- runEitherT . mapEitherT runResourceT $
    traverseView NoIncludeDotFiles (View "test/data/view/deep-view")
  pure $ r === (Left $ WardenTraversalError MaxDepthExceeded)

prop_traverseView_good :: Property
prop_traverseView_good = testIO $ do
  r <- runEitherT . mapEitherT runResourceT $
    traverseView NoIncludeDotFiles (View "test/data/view/good-view")
  pure $ (second (fmap viewFilePath) r) === (Right $ "test/data/view/good-view/year=2015/month=04/day=04/bar" :| [])

prop_traverseView_dotfiles :: Property
prop_traverseView_dotfiles = testIO $ do
  r <- runEitherT . mapEitherT runResourceT $
    traverseView IncludeDotFiles (View "test/data/view/dotfiles-view")
  pure $ (second (fmap viewFilePath) r) === (Right $ "test/data/view/dotfiles-view/year=2015/month=04/day=04/.bar" :| [])

return []
tests :: IO Bool
tests = $forAllProperties $ quickCheckWithResult (stdArgs { maxSuccess = 1 })
