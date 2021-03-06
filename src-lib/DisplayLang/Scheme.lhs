<a name="DisplayLang.Scheme">Schemes</a>
=======

> {-# LANGUAGE TypeOperators, GADTs #-}

> module DisplayLang.Scheme where

> import Control.Applicative
> import Data.Foldable hiding (foldl)
> import Data.Traversable
> import Evidences.Tm
> import Evidences.Mangler
> import Evidences.Eval
> import DisplayLang.DisplayTm

Schemes for implicit arguments
------------------------------

A definition may have a `Scheme`, which allows us to handle implicit
syntax. A `Scheme` is defined by:

| Constructor            | Description           |
|:----------------------:|:---------------------:|
| Ty                     | a real, tangible type |
| (x : Scheme) -> Scheme | an explicit Pi        |
| { x : ty } -> Scheme   | an implicit Pi        |

Crucially, an implicit `Pi` hides a real type, not another scheme: we
forbid "higher-schemes" for mental sanity reasons. For the sake of
generality, we will parameterise over the exact representation of types:

> data Scheme x  =  SchType x
>                |  SchExplicitPi (String :<: Scheme x) (Scheme x)
>                |  SchImplicitPi (String :<: x) (Scheme x)
>   deriving Show

> instance Traversable Scheme where
>     traverse f (SchType t) = SchType <$> f t
>     traverse f (SchExplicitPi (x :<: schS) schT) =
>         SchExplicitPi <$> ((x :<:) <$> traverse f schS) <*> traverse f schT
>     traverse f (SchImplicitPi (x :<: s) schT) =
>         SchImplicitPi <$> ((x :<:) <$> f s) <*> traverse f schT

> instance Functor Scheme where
>     fmap = fmapDefault

> instance Foldable Scheme where
>     foldMap = foldMapDefault

Extracting names
----------------

Given a scheme, we can extract the names of its `Pi`s:

> schemeNames :: Scheme x -> [String]
> schemeNames (SchType _) = []
> schemeNames (SchExplicitPi (x :<: _) sch) = x : schemeNames sch
> schemeNames (SchImplicitPi (x :<: _) sch) = x : schemeNames sch

Turning schemes to terms
------------------------

We can also convert a `Scheme x` to an `x`, if we are given a way to
interpret `Pi`-bindings:

> schemeToType :: (String -> x -> x -> x) -> Scheme x -> x
> schemeToType _ (SchType ty) = ty
> schemeToType piv (SchExplicitPi (x :<: s) t) =
>     piv x (schemeToType piv s) (schemeToType piv t)
> schemeToType piv (SchImplicitPi (x :<: s) t) =
>     piv x s (schemeToType piv t)

With two direct special cases:

> schemeToInTm :: Scheme (InTm x) -> InTm x
> schemeToInTm = schemeToType PIV

> schemeToDInTm :: Scheme (DInTm p x) -> DInTm p x
> schemeToDInTm = schemeToType DPIV

Unlifting schemes
-----------------

Schemes are stored fully `Pi`-lifted with `SchExplicitPi`s, so we may
need to apply them to a spine of shared parameters:

> applyScheme :: Scheme INTM -> [REF] -> Scheme INTM
> applyScheme sch [] = sch
> applyScheme (SchExplicitPi (x :<: SchType s) schT) (r : rs) =
>     applyScheme (underScheme 0 r schT) rs
>   where
>     underScheme :: Int -> REF -> Scheme INTM -> Scheme INTM
>     underScheme n r (SchType ty) = SchType (under n r %% ty)
>     underScheme n r (SchExplicitPi (x :<: schS) schT) =
>         SchExplicitPi (x :<: underScheme n r schS) (underScheme (n+1) r schT)
>     underScheme n r (SchImplicitPi (x :<: s) schT) =
>         SchImplicitPi (x :<: under n r %% s) (underScheme (n+1) r schT)

Schemes in error messages
-------------------------

We can cheaply embed schemes in error messages by converting them to
types and evaluating. Really, we ought to add schemes as a kind of
`ErrorTok`.

> errScheme :: Scheme INTM -> ErrorItem t
> errScheme sch = errTyVal (evTm (schemeToInTm sch) :<: SET)
