module Test.Main where

import Data.Generic.Rep.Show (genericShow)
import Data.Maybe (Maybe)
import Data.Newtype (class Newtype)
import Data.Traversable (class Foldable, class Traversable, for_)
import Effect (Effect)
import Effect.Console (log)
import Partial.Unsafe (unsafePartial)
import Prelude (class Applicative, class Apply, class Bind, class Eq, class Functor, class Monad, class Monoid, class Semigroup, class Show, Unit, compare, const, discard, map, mod, negate, pure, show, unit, (&&), (+), (<), (<$>), (<>), (==), (>), (>=))
import Test.Assert (assert, assertEqual, assertThrows)
import Test.QuickCheck.Arbitrary (class Arbitrary, arbitrary)
import Test.QuickCheck.Laws.Control (checkApplicative, checkApply, checkBind, checkMonad)
import Test.QuickCheck.Laws.Data (checkEq, checkFoldable, checkFunctor, checkMonoid, checkSemigroup)
import Type.Proxy (Proxy(..), Proxy2(..))

import Data.Array as A
import Data.ArrayView (ArrayView, fromArray, toArray)
import Data.ArrayView as AV

-- * set to true to get verbose logs
debug :: Boolean
debug = false


-- * some boilerplate required to bypass OrphanInstances.
newtype ArbitraryAV a = ArbitraryAV (ArrayView a)

instance arbitraryArbitraryAV :: Arbitrary a => Arbitrary (ArbitraryAV a) where
   arbitrary = ArbitraryAV <$> (fromArray <$> arbitrary)

derive instance newtypeArbitraryAV :: Newtype (ArbitraryAV a) _
derive newtype instance semigroupArbitraryAV :: Semigroup (ArbitraryAV a)
derive newtype instance monoidArbitraryAV :: Monoid (ArbitraryAV a)
derive newtype instance eqArbitraryAV :: Eq a => Eq (ArbitraryAV a)
derive newtype instance foldableArbitraryAV :: Foldable ArbitraryAV
derive newtype instance functorArbitraryAV :: Functor ArbitraryAV
derive newtype instance applyArbitraryAV :: Apply ArbitraryAV
derive newtype instance bindArbitraryAV :: Bind ArbitraryAV
derive newtype instance applicativeArbitraryAV :: Applicative ArbitraryAV
derive newtype instance monadArbitraryAV :: Monad ArbitraryAV
derive newtype instance traversableArbitraryAV :: Traversable ArbitraryAV


checkLaws :: Effect Unit
checkLaws = do
  let prx1 = Proxy :: Proxy (ArbitraryAV Int)
      prx2 = (Proxy2 :: Proxy2 ArbitraryAV)
  checkSemigroup prx1
  checkMonoid prx1
  checkEq prx1
  checkFoldable prx2
  checkFunctor prx2
  checkApply prx2
  checkBind prx2
  checkMonad prx2
  checkApplicative prx2


main :: Effect Unit
main = do
  checkLaws

  -- Good old assertion testing.
  -- In our case we need to check some properties after slicing, to ensure that
  -- indices are correct. So relying solely on `quickeck-laws` is not enough.

  -- For all possible lengths...
  for_ (0 A... 12) \len -> do
    let a  = A.range 1 len
        av = AV.range 1 len

    assertEqual { expected: a
                , actual: toArray (fromArray a) }

    logDebug ("-----------------------\n" <>
              " a: "   <> show a <>
              " av: "  <> inspect av)

    -- for all possible indices i & j...
    for_ (-10 A... 10) \i -> do
      for_ (-10 A...10) \j -> do

          -- ...check that slices from i to j are equal
          let aslice = A.slice i j a
              avslice = AV.slice i j av

          logDebug (" len: " <> show len <>
                    " i: "   <> show i <>
                    " j: "   <> show j <>
                    " aslice: " <> show aslice <>
                    " avslice: " <> inspect avslice)

          -- Eq
          assert (avslice == avslice)

          -- Ord
          assertEqual { expected: aslice `compare` aslice
                      , actual: avslice `compare` avslice }
          assertEqual { expected: A.reverse aslice `compare` aslice
                      , actual: AV.reverse avslice `compare` avslice }

          -- fromArray <<< toArray == identity
          assertEqual { expected: avslice
                      , actual: fromArray (toArray avslice) }

          assertEqual { expected: aslice
                      , actual: toArray avslice }

          assertEqual { expected: avslice
                      , actual: fromArray aslice }

          -- null
          assertEqual { expected: A.null aslice
                      , actual: AV.null avslice }

          -- length
          assertEqual { expected: A.length aslice
                      , actual: AV.length avslice }

          -- cons
          assertEqual { expected: A.cons 0 aslice
                      , actual: toArray (AV.cons 0 avslice) }

          -- snoc
          assertEqual { expected: A.snoc aslice 0
                      , actual: toArray (AV.snoc avslice 0) }

          -- head
          assertEqual { expected: A.head aslice
                      , actual: AV.head avslice }

          -- last
          assertEqual { expected: A.last aslice
                      , actual: AV.last avslice }

          -- tail
          assertEqual { expected: A.tail aslice
                      , actual: map toArray (AV.tail avslice) }

          -- init
          assertEqual { expected: A.init aslice
                      , actual: map toArray (AV.init avslice) }

          -- uncons
          assertEqual { expected: A.uncons aslice
                      , actual: map fixTail (AV.uncons avslice) }

          -- unsnoc
          assertEqual { expected: A.unsnoc aslice
                      , actual: map fixInit (AV.unsnoc avslice) }

          -- test functions that require additional index
          for_ (-1 A... 10) \ix -> do
            -- index
            assertEqual  { expected: A.index aslice ix
                         , actual: AV.index avslice ix }

            -- unsafeIndex
            if ix >= 0 && ix < A.length aslice
              then
              assertEqual { expected: unsafePartial (A.unsafeIndex aslice ix)
                          , actual: unsafePartial (AV.unsafeIndex avslice ix) }
              else
              assertThrows \_ ->
              assertEqual { expected: unsafePartial (A.unsafeIndex aslice ix)
                          , actual: unsafePartial (AV.unsafeIndex avslice ix) }

            -- elemIndex
            assertEqual { expected: A.elemIndex ix (aslice <> aslice)
                        , actual: AV.elemIndex ix  (avslice <> avslice) }

            -- elemLastIndex
            assertEqual { expected: A.elemLastIndex ix (aslice <> aslice)
                        , actual: AV.elemLastIndex ix  (avslice <> avslice) }

            -- findIndex
            assertEqual { expected: A.findIndex (_ == ix) (aslice <> aslice)
                        , actual: AV.findIndex (_ == ix)  (avslice <> avslice) }

            -- findLastIndex
            assertEqual { expected: A.findIndex (_ == ix) (aslice <> aslice)
                        , actual: AV.findIndex (_ == ix)  (avslice <> avslice) }

            -- insertAt
            assertEqualsMaybe
              (AV.insertAt ix ix avslice)
              (A.insertAt ix ix aslice)

            -- deleteAt
            assertEqualsMaybe
              (AV.deleteAt ix avslice)
              (A.deleteAt ix aslice)

            -- updateAt
            assertEqualsMaybe
              (AV.updateAt ix 0 avslice)
              (A.updateAt ix 0 aslice)

            -- modifyAt
            assertEqualsMaybe
              (AV.modifyAt ix (_ + 1) avslice)
              (A.modifyAt ix (_ + 1) aslice)

            -- modifyAtIndices
            -- alterAt
            -- reverse
            -- concat
            -- concatMap

            -- slice
            assertEquals
              (AV.slice i ix avslice)
              (A.slice  i ix aslice)

            -- partition
            -- filterA
            -- mapMaybe
            -- catMaybes
            -- mapWithIndex
            -- sort
            -- sortBy
            -- sortWith

          -- test functions that require a predicate
          for_ [ (_ > 5)
               , const false
               , const true
               , (\x -> x `mod` 2 == 1)
               , (\x -> x `mod` 2 == 0)
               , (_ < 5) ] \f -> do

            -- span
            assertEqual { expected: fixInitRest (A.span f aslice)
                        , actual: AV.span f avslice }

            -- filter
            assertEquals
              (AV.filter f avslice)
              (A.filter f aslice)

fixTail :: forall a. { tail :: ArrayView a, head :: a } -> { head :: a, tail :: Array a }
fixTail { head, tail } = { head, tail: toArray tail }

fixInit :: forall a. { init :: ArrayView a, last :: a } -> { last :: a, init :: Array a }
fixInit { last, init } = { last, init: toArray init }

fixInitRest :: forall a. { rest :: Array a, init :: Array a } -> { init :: ArrayView a, rest :: ArrayView a }
fixInitRest { init, rest } = { init: fromArray init
                             , rest: fromArray rest }

assertEquals :: forall a. Eq a => Show a => ArrayView a -> Array a -> Effect Unit
assertEquals av a = do
  assertEqual { expected: av
              , actual: fromArray a }
  assertEqual { expected: a
              , actual: toArray av }

assertEqualsMaybe :: forall a. Eq a => Show a => Maybe (ArrayView a) -> Maybe (Array a) -> Effect Unit
assertEqualsMaybe av a = do
  assertEqual { expected: av
              , actual: map fromArray a }
  assertEqual { expected: a
              , actual: map toArray av }

logDebug :: String -> Effect Unit
logDebug = if debug then log else const (pure unit)

inspect :: forall a. Show a => ArrayView a -> String
inspect = genericShow
