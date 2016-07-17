module Lib
    ( libMain
    ) where

import           Control.Monad         (when)
import           Data.ByteString       (ByteString (..), concat, hGetContents,
                                        intercalate, isPrefixOf)
import           Data.ByteString.Char8 (lines, pack, singleton, unpack)
import           Data.Char             (digitToInt, ord)
import           Data.List             (elemIndex)
import           Data.List.Split       (keepDelimsL, split, whenElt)
import           Data.Maybe            (fromMaybe)
import           Data.String.Utils     (startswith)
import qualified Data.Text             as T
import           Data.Text.ICU.Convert (open, toUnicode)
import qualified Data.Text.IO          as T
import           Data.Word             (Word8 (..))
import           Prelude               hiding (lines)
import           System.IO             (BufferMode (..), IOMode (..),
                                        hSetBuffering, openFile, stdin)

data Question = Question {
    statement :: ByteString
  , options   :: [ByteString]
  , answer    :: Int
}

data QuestionGroup = QuestionGroup {
    difficulty :: ByteString
  , questions  :: [Question]
}

type ProgramData = [QuestionGroup]

mapIndChar :: (a -> Char -> b) -> [a] -> [b]
mapIndChar f l = zipWith f l ['a'..]

mapInd :: (a -> Int -> b) -> [a] -> [b]
mapInd f l = zipWith f l [0..]

group :: Int -> [a] -> [[a]]
group _ [] = []
group n l
  | n > 0 = take n l : group n (drop n l)
  | otherwise = error "Negative n"

byteStringToString :: ByteString -> IO String
byteStringToString s = do
    conv <- open "utf-8" Nothing
    return (T.unpack $ toUnicode conv s)

byteStringToInt :: ByteString -> Int
byteStringToInt s = read (unpack s) :: Int

-- Takes a question and the index of the answer (0, 1, 2 or 3)
presentQuestion :: Question -> IO Bool
presentQuestion q = do
    let stmt = statement q
        opts = options q
        -- The answers are 1-indexed (instead of 0), so we need to subtract 1 to offset it
        ans = answer q - 1
        indexedOpts = mapIndChar (\x i -> Data.ByteString.concat ([singleton i] ++ [pack ") "] ++ [x])) opts
    byteStringToString stmt >>= putStrLn
    byteStringToString (intercalate (pack "\n") indexedOpts) >>= putStrLn
    putStrLn "Resposta? "
    answr <- getChar
    let maybeAnswer = elemIndex answr ['a'..]
        didAnswerCorrectly = maybeAnswer == Just ans
    if didAnswerCorrectly
      then putStrLn "\nCerta resposta!\n"
      else putStrLn ("\nResposta errada. Sua resposta foi " ++ [answr])
    return didAnswerCorrectly

-- Converts an array of strings (with 5 elements) into a Question object
listToQuestion :: (Int, [ByteString]) -> Question
listToQuestion a =
    let ans = fst a
        (x:xs) = snd a
    in Question x xs ans

-- Builds a QuestionGroup based on a nested array of ByteStrings, where the head of each group
-- is the header and the tail are the groups of questions (with 5 elements each)
listToQuestionGroups :: [Int] -> [[ByteString]] -> QuestionGroup
listToQuestionGroups a xs = QuestionGroup (head $ head xs) (zipWith (curry listToQuestion) a (tail xs))

-- Split an array using the function for selecting the delimiter. The resulting array includes
-- the delimiter as the first item in the array. This is important because we need the headers for
-- each question group (Facil, Medio and Dificil)
splitWhen :: (a -> Bool) -> [a] -> [[a]]
splitWhen = split . keepDelimsL . whenElt

-- This groups questions in lists of 5 elements, where:
-- 1st item is the question statement
-- items 2, 3, 4 and 5 are the question possible answers (a, b, c or d)
-- The list head is the title of the question group (either ### Facil, ### Medio or ### Dificil),
-- so that is not included in the grouping
questionGroup :: [ByteString] -> [[ByteString]]
questionGroup (x:xs) = [x] : group 5 xs

parseGroupsWithAnswers :: [Int] -> [[[ByteString]]] -> [QuestionGroup]
parseGroupsWithAnswers a (x:xs) =
    let totalQuestions = length x
        thisGroup = listToQuestionGroups (take totalQuestions a) x
        remainder = parseGroupsWithAnswers (drop totalQuestions a) xs
    in thisGroup : remainder

-- This array should have 4 items
-- 1st item - [[ByteString]] of Easy questions
-- 2nd item - [[ByteString]] of Medium questions
-- 3rd item - [[ByteString]] of Hard questions
-- 4rd item - [[ByteString]] of answers - This needs to be flattened into a [ByteString] with concat
buildProgramData :: [[[ByteString]]] -> ProgramData
buildProgramData xs =
    let answers = map byteStringToInt (tail $ Prelude.concat (last xs))
        groups = parseGroupsWithAnswers answers (init xs)
    in groups

-- Takes a ByteString with the input file contents and parse it into a ProgramData object
parseSections :: IO ByteString -> IO ProgramData
parseSections bs =
    let nonEmptyString = filter (/= pack "")
        isSectionMarker = isPrefixOf (pack "###")
        allLines = fmap lines bs
        sections = fmap (filter (not . null) . splitWhen isSectionMarker) allLines
        groupedQuestionListBySection = fmap (map (questionGroup . nonEmptyString)) sections
    in fmap buildProgramData groupedQuestionListBySection

doWhileM :: (a -> IO Bool) -> [a] -> IO Bool
doWhileM _ [] = return False
doWhileM m (x:xs) = do
    res <- m x
    if res
      then doWhileM m xs
      else return False

printQuestionGroup :: QuestionGroup -> IO Bool
printQuestionGroup g = do
    byteStringToString (difficulty g) >>= putStrLn
    doWhileM presentQuestion (questions g)

printQuestionGroups :: ProgramData -> IO ()
printQuestionGroups pd = do
    let (x:xs) = pd
    res <- printQuestionGroup x
    when res $ printQuestionGroups xs

libMain :: IO ()
libMain = do
    -- We need to disable stdin buffering otherwise getChar won't work well
    hSetBuffering stdin NoBuffering
    let file = openFile "questions.txt" ReadMode >>= hGetContents
    parseSections file >>= printQuestionGroups
