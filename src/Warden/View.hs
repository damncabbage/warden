{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Warden.View(
    traverseView
  , traverseView'
  , traverseDirectory
) where

import           Control.Monad.IO.Class (liftIO)
import           Control.Monad.Trans.Resource (ResourceT)

import           Data.List (zip)
import           Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NE

import           P

import           System.Directory (getDirectoryContents)
import           System.IO (IO)
import           System.Posix.Files (getSymbolicLinkStatus, isRegularFile, isDirectory)

import           Warden.Data
import           Warden.Error

import           X.Control.Monad.Trans.Either (EitherT, left)

traverseView :: IncludeDotFiles
             -> View
             -> EitherT WardenError (ResourceT IO) (NonEmpty ViewFile)
traverseView idf v = do
  (bads, goods) <- traverseView' idf v
  when (not $ null bads) $
    left . WardenTraversalError $ NonViewFiles bads
  when (null goods) $
    left $ WardenTraversalError EmptyView
  pure $ NE.fromList goods

traverseView' :: IncludeDotFiles
              -> View
              -> EitherT WardenError (ResourceT IO) ([NonViewFile], [ViewFile])
traverseView' idf v = do
  fs <- directoryFiles <$> traverseDirectory idf (MaxDepth 5) [] (DirName $ unView v)
  pure . first (fmap NonViewFile) $ (partitionEithers $ viewFile <$> fs)

-- | Traverse a directory tree to a maximum depth, ignoring hidden files.
traverseDirectory :: IncludeDotFiles
                  -> MaxDepth
                  -> [DirName]
                  -> DirName
                  -> EitherT WardenError (ResourceT IO) DirTree
traverseDirectory _ (MaxDepth 0) _ _ = left $ WardenTraversalError MaxDepthExceeded
traverseDirectory idf (MaxDepth depth) preds dn =
  let preds' = preds <> [dn] in do
  ls <- liftIO . getDirectoryContents $ joinDir preds'
  sts <- liftIO . mapM getSymbolicLinkStatus $ (joinFile preds') <$> ls
  let branches = fmap (DirName . fst) $
                   filter (uncurry visitable) $ zip ls sts
  let leaves = fmap (FileName . fst) $ filter (uncurry validLeaf) $ zip ls sts
  subtrees <- mapM (traverseDirectory idf (MaxDepth $ depth - 1) preds') branches
  pure $ DirTree dn subtrees leaves
  where
    visitable ('.':_) _ = False
    visitable ('_':_) _ = False
    visitable _ st      = isDirectory st

    validLeaf ('.':_) st = idf == IncludeDotFiles && isRegularFile st
    validLeaf ('_':_) _ = False
    validLeaf _ st      = isRegularFile st
