Display Terms
=============

> {-# LANGUAGE TypeOperators, GADTs, KindSignatures, RankNTypes,
>     TypeSynonymInstances, FlexibleInstances, FlexibleContexts,
>     ScopedTypeVariables, PatternSynonyms,
>     DeriveFunctor, DeriveFoldable, DeriveTraversable #-}

> module DisplayLang.DisplayTm where

> import Control.Applicative
> import Data.Foldable hiding (foldl)
> import Data.Functor.Identity
> import Data.Traversable

> import Evidences.Tm
> import Kit.MissingLibrary

Structure of Display Terms
--------------------------

Display terms mirror and extend the `Tm d` terms of the
Evidence language. While the Evidence language is the language of the
type-checker, the Display language is the one of humans in an
interactive development. Hence, in addition to the terms from the
Evidence language, we have the following:

-   Question marks (holes), which are turned into subgoals during
    elaboration (Chapter [chap:elaboration])

-   Underscores (jokers), which are inferred during elaboration

-   Embedding of evidence terms into display terms

-   Type annotations

-   Feature-specific extensions, which are imported from an aspect.

However, we have removed the following:

-   Type ascriptions, replaced by type annotations

-   Operators, replaced by a parameter containing the corresponding
    reference in `primitives`
    (Section [Evidences.Operators](#Evidences.Operators))

Because of a limitation of GHC `deriving Traversable`, we define two
mutually recursive data types instead of taking a `Dir` parameter.
Thanks to this hack, we can use `deriving Traversable`.

> data DInTm :: * -> * -> * where
>     DL     :: DScope p x       ->  DInTm p x -- lambda
>     DC     :: Can (DInTm p x)  ->  DInTm p x -- canonical
>     DN     :: DExTm p x        ->  DInTm p x -- neutral
>     DQ     :: String           ->  DInTm p x -- hole
>     DU     ::                      DInTm p x -- underscore
>     DT     :: InTmWrap p x     ->  DInTm p x -- embedding
>     DAnchor :: String -> DInTm p x -> DInTm p x
>     DEqBlue :: DExTm p x -> DExTm p x -> DInTm p x
>     DIMu :: Labelled (Identity :*: Identity) (DInTm p x)
>          -> DInTm p x
>          -> DInTm p x
>     DTag :: String -> [DInTm p x] -> DInTm p x
>  deriving (Functor, Foldable, Traversable, Show)

> data DExTm p x = DHead p x ::$ DSpine p x
>   deriving (Functor, Foldable, Traversable, Show)

> data DHead :: * -> * -> * where
>     DP     :: x                -> DHead  p x -- parameter
>     DType  :: DInTm p x        -> DHead  p x -- type annotation
>     DTEx   :: ExTmWrap p x     -> DHead  p x -- embedding
>  deriving (Functor, Foldable, Traversable, Show)

Note that, again, we are polymorphic in the representation of free
variables. The variables in Display terms are denoted here by `x`. The
variables of embedded Evidence terms are denoted by `p`. Hence, there is
two potentially distinct set of free variables.

While we reuse the `Can` and `Elim` functors from `Tm`, we redefine the
notion of scope. We store `DExTm`s so as to give easy access to the head
and spine for elaboration and pretty-printing.

> dfortran :: DInTm p x -> String
> dfortran (DL (x ::. _)) | not (null x) = x
> -- A user should never see this name. I (joel) am not sure whether that's
> -- currently the case, but when binding non-constants, the previous case
> -- gives the name.
> dfortran _ = "_"

Scopes, canonical objects and eliminators

The `DScope` functor is a simpler version of the `Scope` functor: we
only ever consider *terms* here, while `Scope` had to deal with
*values*. Hence, we give this purely syntaxic, first-order
representation of scopes:

> data DScope :: * -> * -> * where
>     (::.)  :: String -> DInTm p x  -> DScope p x  -- binding
>     DK     :: DInTm p x            -> DScope p x  -- constant
>   deriving (Functor, Foldable, Traversable, Show)

We provide handy projection functions to get the name and body of a
scope:

> dScopeName :: DScope p x -> String
> dScopeName (x ::. _)  = x
> dScopeName (DK _)     = "_"

> dScopeTm :: DScope p x -> DInTm p x
> dScopeTm (_ ::. tm)  = tm
> dScopeTm (DK tm)     = tm

Spines of eliminators are just like in the evidence language:

> type DSpine p x = [Elim (DInTm p x)]
> ($::$) :: DExTm p x -> Elim (DInTm p x) -> DExTm p x
> (h ::$ s) $::$ a = h ::$ (s ++ [a])

Embedding evidence terms

The `DT` and `DTEx` constructors allow evidence terms to be treated as
`In` and `Ex` display terms, respectively. This is useful for
elaboration, because it allows the elaborator to combine finished terms
with display syntax and continue elaborating. Such terms cannot be
pretty-printed, however, so they should not be used in the distiller.

To make `deriving Traversable` work properly, we have to `newtype`-wrap
them and manually give trivial `Traversable` instances for the wrappers.
The instantiation code is hidden in the literate document.

> newtype InTmWrap p x = InTmWrap (InTm p) deriving (Show, Functor, Foldable)
> newtype ExTmWrap p x = ExTmWrap (ExTm p) deriving (Show, Functor, Foldable)

> pattern DTIN x = DT (InTmWrap x)
> pattern DTEX x = DTEx (ExTmWrap x)

> instance Traversable (InTmWrap p) where
>   traverse f (InTmWrap x) = pure (InTmWrap x)

> instance Traversable (ExTmWrap p) where
>   traverse f (ExTmWrap x) = pure (ExTmWrap x)

The following are essentially saying that `DInTm` is traversable in its
first argument, as well as its second.

> traverseDTIN :: Applicative f => (p -> f q) -> DInTm p x -> f (DInTm q x)
> traverseDTIN f (DL (x ::. tm)) = DL <$> ((x ::.) <$> traverseDTIN f tm)
> traverseDTIN f (DL (DK tm)) = DL <$> (DK <$> traverseDTIN f tm)
> traverseDTIN f (DC c) = DC <$> traverse (traverseDTIN f) c
> traverseDTIN f (DN n) = DN <$> traverseDTEX f n
> traverseDTIN _ (DQ s) = pure (DQ s)
> traverseDTIN _ DU     = pure DU
> traverseDTIN f (DTIN tm) = DTIN <$> traverse f tm
> traverseDTIN f (DAnchor s args) = DAnchor s <$> traverseDTIN f args
> traverseDTIN f (DEqBlue t u) =
>     DEqBlue <$> traverseDTEX f t <*> traverseDTEX f u
> traverseDTIN f (DIMu s i) = DIMu
>     <$> traverse (traverseDTIN f) s
>     <*> traverseDTIN f i
> traverseDTIN f (DTag s xs) = DTag s <$> traverse (traverseDTIN f) xs

> traverseDTEX :: Applicative f => (p -> f q) -> DExTm p x -> f (DExTm q x)
> traverseDTEX f (h ::$ as) =
>     (::$) <$> traverseDHead f h <*> traverse (traverse (traverseDTIN f)) as

> traverseDHead :: Applicative f => (p -> f q) -> DHead p x -> f (DHead q x)
> traverseDHead _ (DP x) = pure (DP x)
> traverseDHead f (DType tm) = DType <$> traverseDTIN f tm
> traverseDHead f (DTEX tm) = DTEX <$> traverse f tm

Type annotations

Because type ascriptions are horrible things to parse[^1], in the
display language we use type annotations instead. The type annotation
`DType ty` gets elaborated to the identity function for type `ty`,
thereby pushing the type into its argument. The distiller removes type
ascriptions and replaces them with appropriate type annotations if
necessary.

Useful Abbreviations
--------------------

The convention for display term pattern synonyms is that they should
match their evidence term counterparts, but with the addition of `D`s in
appropriate places.

> pattern DSET        = DC Set
> pattern DARR s t    = DPI s (DL (DK t))
> pattern DPI s t     = DC (Pi s t)
> pattern DCON t      = DC (Con t)
> pattern DNP n       = DN (DP n ::$ [])
> pattern DLAV x t    = DL (x ::. t)
> pattern DPIV x s t  = DPI s (DLAV x t)
> pattern DLK t       = DL (DK t)
> pattern DTY ty tm   = DType ty ::$ [A tm]
> pattern DANCHOR s args = DAnchor s args

Desc

> pattern DMU l x        = DC (Mu (l :?=: Identity x))
> pattern DIDD           = DCON (DPAIR  DZE
>                                       DVOID)
> pattern DCONSTD x      = DCON (DPAIR  (DSU DZE)
>                                       (DPAIR x DVOID))
> pattern DSUMD e b      = DCON (DPAIR  (DSU (DSU DZE))
>                                       (DPAIR e (DPAIR b DVOID)))
> pattern DPRODD u d d'  = DCON (DPAIR  (DSU (DSU (DSU DZE)))
>                                       (DPAIR u (DPAIR d (DPAIR d' DVOID))))
> pattern DSIGMAD s t    = DCON (DPAIR  (DSU (DSU (DSU (DSU DZE))))
>                                       (DPAIR s (DPAIR t DVOID)))
> pattern DPID s t       = DCON (DPAIR  (DSU (DSU (DSU (DSU (DSU DZE)))))
>                                       (DPAIR s (DPAIR t DVOID)))

> pattern DENUMT e    = DC (EnumT e)
> pattern DNILE       = DCON (DPAIR DZE DVOID)
> pattern DCONSE t e  = DCON (DPAIR (DSU DZE) (DPAIR t (DPAIR e DVOID)))
> pattern DZE         = DC Ze
> pattern DSU n       = DC (Su n)
> pattern DMONAD d x = DC (Monad d x)
> pattern DRETURN x  = DC (Return x)
> pattern DCOMPOSITE t = DC (Composite t)
> pattern DIVARN     = DZE
> pattern DICONSTN   = DSU DZE
> pattern DIPIN      = DSU (DSU DZE)
> pattern DIFPIN     = DSU (DSU (DSU DZE))
> pattern DISIGMAN   = DSU (DSU (DSU (DSU DZE)))
> pattern DIFSIGMAN  = DSU (DSU (DSU (DSU (DSU DZE))))
> pattern DIPRODN    = DSU (DSU (DSU (DSU (DSU (DSU DZE)))))
> pattern DIMU l ii x i  = DIMu (l :?=: (Identity ii :& Identity x)) i
> pattern DIVAR i        = DCON (DPAIR DIVARN     (DPAIR i DVOID))
> pattern DIPI s t       = DCON (DPAIR DIPIN      (DPAIR s (DPAIR t DVOID)))
> pattern DIFPI s t      = DCON (DPAIR DIFPIN     (DPAIR s (DPAIR t DVOID)))
> pattern DISIGMA s t    = DCON (DPAIR DISIGMAN   (DPAIR s (DPAIR t DVOID)))
> pattern DIFSIGMA s t   = DCON (DPAIR DIFSIGMAN  (DPAIR s (DPAIR t DVOID)))
> pattern DICONST p      = DCON (DPAIR DICONSTN   (DPAIR p DVOID))
> pattern DIPROD u x y   = DCON (DPAIR DIPRODN    (DPAIR u (DPAIR x (DPAIR y DVOID))))
> pattern DLABEL l t = DC (Label l t)
> pattern DLRET t    = DC (LRet t)
> pattern DNU l t = DC (Nu (l :?=: Identity t))
> pattern DCOIT d sty f s = DC (CoIt d sty f s)
> pattern DPROP        = DC Prop
> pattern DPRF p       = DC (Prf p)
> pattern DALL p q     = DC (All p q)
> pattern DIMP p q     = DALL (DPRF p) (DL (DK q))
> pattern DALLV x s p  = DALL s (DLAV x p)
> pattern DAND p q     = DC (And p q)
> pattern DTRIVIAL     = DC Trivial
> pattern DABSURD      = DC Absurd
> pattern DBOX p       = DC (Box p)
> pattern DINH ty      = DC (Inh ty)
> pattern DWIT t       = DC (Wit t)
> pattern DQUOTIENT x r p = DC (Quotient x r p)
> pattern DCLASS x        = DC (Con x)
> pattern DRSIG         = DC RSig
> pattern DREMPTY       = DC REmpty
> pattern DRCONS s i t  = DC (RCons s i t)
> pattern DRECORD l s   = DC (Record (l :?=: Identity s))
> pattern DSIGMA p q = DC (Sigma p q)
> pattern DPAIR  p q = DC (Pair p q)
> pattern DUNIT      = DC Unit
> pattern DVOID      = DC Void
> pattern DTimes x y = Sigma x (DL (DK y))
> pattern DTIMES x y = DC (DTimes x y)
> pattern DUID    = DC UId
> pattern DTAG s  = DTag s []

Sizes
-----

We keep track of the `Size` of terms when parsing, to avoid nasty left
recursion, and when pretty-printing, to minimise the number of brackets
we output. In increasing order, the sizes are:

> data Size = ArgSize | AppSize | EqSize | AndSize | ArrSize | PiSize
>   deriving (Show, Eq, Enum, Bounded, Ord)

When a higher-size term has to be put in a lower-size position, it must
be wrapped in parentheses. For example, an application has `AppSize` but
its arguments have `ArgSize`, so `g (f x)` cannot be written `g f x`,
whereas `EqSize` is bigger than `AppSize` so `f x == g x` means the same
thing as `(f x) == (g x)`.

[^1]: Left nesting is not really a friend of our damn parser
