import Prelude hiding (lines)
import Data.List
    ( elemIndex
    )
import Data.String.Utils
    ( startswith
    )
import Data.List.Split
    ( splitWhen
    )
import System.IO
    ( openFile
    , IOMode(..)
    )
import qualified Data.Text as T
import qualified Data.Text.IO as T
import Data.ByteString
    ( ByteString(..)
    , hGetContents
    , intercalate
    , isPrefixOf
    )
import Data.ByteString.Char8
    ( pack
    , unpack
    , lines
    )
import Data.Text.ICU.Convert
    ( open
    , toUnicode
    )


data Question = Question {
      statement   :: ByteString
    , options     :: [ByteString]
    , answer      :: Int
}

-- variant of map that passes each element's index as a second argument to f
mapInd :: (a -> Char -> b) -> [a] -> [b]
mapInd f l = zipWith f l ['a'..]

group :: Int -> [a] -> [[a]]
group _ [] = []
group n l
  | n > 0 = (take n l) : (group n (drop n l))
  | otherwise = error "Negative n"

byteStringToString conv s = T.unpack $ toUnicode conv s

presentQuestion :: Question -> IO Bool
presentQuestion q = do
    let stmt = statement q
        opts = options q
        correct_answer = answer q
        indexedOpts = mapInd (\x i -> [i] ++ ") " ++ x) opts
    putStr stmt
    putStrLn (foldl (\a b -> a ++ "\n" ++ b) "" indexedOpts)
    putStrLn "Resposta? "
    answr <- getChar
    let intAnswr = elemIndex answr ['a'..]
    return (intAnswr == Just correct_answer)

listToQuestion :: [ByteString] -> Question
listToQuestion (x:xs) = Question x xs 1

parseSections :: ByteString -> [[Question]]
parseSections bs =
    let nonEmptyString = filter (not . (== (pack "")))
        isSectionMarker = isPrefixOf $ pack "###"
        questionGroup = group 5
        allLines = lines bs
        sections = filter (not . null) $ splitWhen isSectionMarker allLines
        groupedQuestionListBySection = map questionGroup $ map nonEmptyString sections
        answers = last groupedQuestionListBySection
    in map (map listToQuestion) (init groupedQuestionListBySection)

main :: IO ()
main = do
    h <- openFile "questions.txt" ReadMode
    bs <- hGetContents h
    conv <- open "utf-8" Nothing
    let sections = parseSections bs
    let easy = sections !! 0
    let medium = sections !! 1
    let hard = sections !! 2
    result <- presentQuestion (medium !! 0)
    putStrLn  (show result)
    return ()
    -- putStrLn $ byteStringToString conv (intercalate (pack "\n") (easy !! 0))
    -- let questions = [ Question {
    --       statement = "Em que estado brasileiro nasceu a apresentadora Xuxa?"
    --     , options = [ "Rio de Janeiro", "Rio Grande do Sul", "Santa Catarina", "Goiás" ]
    --     , answer = 1
    --   }]
    -- result <- presentQuestion (questions !! 0)
    -- putStrLn (if result)
    -- return ()