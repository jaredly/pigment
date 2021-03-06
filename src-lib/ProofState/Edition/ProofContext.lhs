<a name="ProofState.Edition.ProofContext">Proof Context</a>
=============

> {-# LANGUAGE FlexibleInstances, TypeOperators, TypeSynonymInstances,
>              GADTs, RankNTypes, StandaloneDeriving #-}
> module ProofState.Edition.ProofContext where

> import Control.Applicative
> import Data.Foldable
> import Data.List
> import qualified Data.Text as T
> import Data.Traversable

> import NameSupply.NameSupply
> import ProofState.Structure.Developments
> import ProofState.Edition.News
> import Evidences.Tm
> import Kit.BwdFwd

Recall from Section [ProofState.Structure.Developments](#ProofState.Structure.Developments) the
definition of a development:

    type Dev = (f (Entry f), Tip, NameSupply)

We `unzip` (cf. Huet's Zipper @huet:zipper) this type to produce a
type representing its one-hole context. This allows us to keep track of
the location of a working development and perform local navigation
easily.

The derivative: `Layer`
-----------------------

Hence, we define `Layer` by unzipping `Dev`. Each `Layer` of the zipper
is a record with the following fields:

* `aboveEntries` - appearing *above* the working development
* `currentEntry` - data about the working development
* `belowEntries` - appearing *below* the working development
* `layTip` - the `Tip` of the development that contains the current entry
* `layNSupply` - the `NameSupply` of the development that contains the current
    entry
* `laySuspendState` - the state of the development that contains the current
    entry

> data Layer = Layer
>   {  aboveEntries     :: Entries
>   ,  currentEntry     :: CurrentEntry
>   ,  belowEntries     :: NewsyEntries
>   ,  layTip           :: Tip
>   ,  layNSupply       :: NameSupply
>   ,  laySuspendState  :: SuspendState
>   }
>  deriving Show

The derivative makes sense only for definitions and modules, which have
sub-developments. Parameters being childless, they ‘derive to 0'. Hence, the
data about the working development is the derivative of the Definition and
Module data-types defined in
Section [ProofState.Structure.Developments.entry](#ProofState.Structure.Developments.entry).

> data CurrentEntry
>     = CDefinition DefKind REF (String, Int) INTM EntityAnchor Metadata
>     | CModule Name ModulePurpose Metadata
>     deriving Show

One would expect the `belowEntries` to be an `Entries`, just as the
`aboveEntries`. However, the `belowEntries` needs to be a richer structure to
support the news infrastructure
(Section [ProofState.Edition.News](#ProofState.Edition.News)). Indeed, we
propagate reference updates lazily, by pushing news bulletin below the current
cursor.

Hence, the `belowEntries` are not only normal entries but also contain
news. We define a `newtype` for the composition of the `Fwd` and `Either
NewsBulletin` functors, and use this functor for defining the type of
`belowEntries`.

> newtype NewsyFwd x = NF { unNF :: Fwd (Either NewsBulletin x) }
> type NewsyEntries = NewsyFwd (Entry NewsyFwd)

Note that `aboveEntries` are `Entries`, that is `Bwd` list.
`belowEntries` are `NewsyEntries`, hence `Fwd` list. This justifies some
piece of kit to deal with this global context.

> deriving instance Show (Dev NewsyFwd)

> instance Show (NewsyFwd (Entry NewsyFwd)) where
>     show (NF ls) = show ls

> instance Show (Entry NewsyFwd) where
>     show (EEntity ref xn e t a _) = unwords
>         ["\"E", show ref, show xn, show e, show t, show a, "\""]
>     show (EModule n d p _) = unwords
>         ["M", show n, show d, show p]

> instance Show (Entity NewsyFwd) where
>     show (Parameter k) = "(Param " ++ show k ++ ")"
>     show (Definition k d) = "(Def " ++ show k ++ " " ++ show d ++ ")"

> instance Traversable NewsyFwd where
>     traverse g (NF x) = NF <$> traverse (traverse g) x

> instance Foldable NewsyFwd where
>     foldMap = foldMapDefault

> instance Functor NewsyFwd where
>     fmap = fmapDefault

The Zipper: `ProofContext`
--------------------------

Once we have the derivative, the zipper is almost here. The proof
context is represented by a stack of layers (`pcLayers`), ending with
the working development (`pcAboveCursor`) above the cursor and the
entries below the cursor (`pcBelowCursor`)..

> data ProofContext = PC
>     {  pcLayers       :: Bwd Layer
>     ,  pcAboveCursor  :: Dev Bwd
>     ,  pcBelowCursor  :: Fwd (Entry Bwd)
>     }
>   deriving Show

The `emptyContext` corresponds to the following (intentionally verbose)
definition:

> emptyContext :: ProofContext
> emptyContext = PC  {  pcLayers = B0
>                    ,  pcAboveCursor = Dev  {  devEntries       = B0
>                                            ,  devTip           = Module
>                                            ,  devNSupply       = (B0, 0)
>                                            ,  devSuspendState  = SuspendNone }
>                    ,  pcBelowCursor = F0 }
