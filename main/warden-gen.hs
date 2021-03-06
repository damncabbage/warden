{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE LambdaCase #-}

import           BuildInfo_ambiata_warden
import           DependencyInfo_ambiata_warden

import           P

import           System.Exit (exitSuccess)
import           System.IO (IO, print, putStrLn)

import           Test.IO.Warden

import           Warden.Data

import           X.Options.Applicative

data LongLines =
    LongLines
  | NoLongLines
  deriving (Eq, Show)

data Command = Generate RecordCount GenSize LongLines GenType
  deriving (Eq, Show)

main :: IO ()
main = do
  dispatch (safeCommand wardenGenP) >>= \case
    VersionCommand -> do
      putStrLn ("warden-gen: " <> buildInfoVersion)
    DependencyCommand -> do
      mapM_ putStrLn dependencyInfo
    RunCommand DryRun c -> do
      print c
      exitSuccess
    RunCommand RealRun (Generate c s ll gt) -> do
      vp <- generateView gt "." c s $ longLinesParam ll
      putStrLn $ unView vp

longLinesParam :: LongLines -> LineSize
longLinesParam LongLines   = LineSize 10000
longLinesParam NoLongLines = LineSize 20

wardenGenP :: Parser Command
wardenGenP = subparser $
  command' "gen" "Generate a view for testing/benchmarking." generateP

generateP :: Parser Command
generateP = Generate
  <$> recordCountP
  <*> genSizeP
  <*> longLinesP
  <*> genTypeP

recordCountP :: Parser RecordCount
recordCountP = RecordCount <$> (option auto $
     long "record-count"
  <> short 'c'
  <> metavar "COUNT"
  <> value 1000000
  <> help "Number of records to generate (default 10^6).")

genSizeP :: Parser GenSize
genSizeP = GenSize <$> (option auto $
     long "gen-size"
  <> short 's'
  <> metavar "SIZE"
  <> value 4
  <> help "Generator size parameter, default 4.")

longLinesP :: Parser LongLines
longLinesP = flag NoLongLines LongLines $
     long "long-lines"
  <> short 'l'
  <> help "Generate very long lines."

genTypeP :: Parser GenType
genTypeP = (maybe NonDeterministic Deterministic) <$> (optional . option auto $
     long "deterministic"
  <> short 'd'
  <> metavar "SEED"
  <> help "Use a deterministic generator with specified seed (default is nondeterministic).")
