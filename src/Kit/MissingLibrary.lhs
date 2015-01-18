Missing Library
===============

> {-# LANGUAGE FlexibleInstances, FlexibleContexts, MultiParamTypeClasses, TypeFamilies, TypeOperators, UndecidableInstances, TypeSynonymInstances #-}

> module Kit.MissingLibrary where

> import Control.Applicative
> import Control.Newtype
> import Control.Monad.Writer
> import Data.Foldable
> import Data.Traversable

Renaming
--------

> trail :: (Applicative f, Foldable t, Monoid (f a)) => t a -> f a
> trail = foldMap pure

> (^$) :: (Traversable f, Applicative i) => (s -> i t) -> f s -> i (f t)
> (^$) = traverse

> iter :: (a -> b -> b) -> [a] -> b -> b
> iter = flip . Prelude.foldr

Missing Instances
-----------------

> instance (Applicative f, Num x, Show (f x), Eq (f x)) => Num (f x) where
>   x + y          = (+) <$> x <*> y
>   x * y          = (*) <$> x <*> y
>   x - y          = (-) <$> x <*> y
>   abs x          = abs <$> x
>   negate x       = negate <$> x
>   signum x       = signum <$> x
>   fromInteger i  = pure $ fromInteger i

Grr.

> instance Monoid (IO ()) where
>   mempty = return ()
>   mappend x y = do x; y

HalfZip
-------

> class Functor f => HalfZip f where
>   halfZip :: f x -> f y -> Maybe (f (x,y))

Functor Kit
-----------

> newtype Id       x = Id {unId :: x}        deriving Show
> newtype Ko a     x = Ko {unKo :: a}        deriving Show
> data (p :+: q)  x = Le (p x) | Ri (q x)    deriving Show
> data (p :*: q)  x = p x :& q x             deriving Show

> instance Functor Id where
>   fmap f (Id x) = Id (f x)

> instance Functor (Ko a) where
>   fmap _ (Ko a) = Ko a

> instance (Functor p, Functor q) => Functor (p :+: q) where
>   fmap f (Le px)  = Le (fmap f px)
>   fmap f (Ri qx)  = Ri (fmap f qx)

> instance (Functor p, Functor q) => Functor (p :*: q) where
>   fmap f (px :& qx)  = fmap f px :& fmap f qx

> instance Foldable Id where
>   foldMap = foldMapDefault

> instance Foldable (Ko a) where
>   foldMap = foldMapDefault

> instance (Traversable p, Traversable q) => Foldable (p :+: q) where
>     foldMap = foldMapDefault

> instance (Traversable p, Traversable q) => Foldable (p :*: q) where
>     foldMap = foldMapDefault

TODO replace with version from recursion-schemes

> newtype Fix f = InF (f (Fix f))  -- tying the knot

> instance Show (f (Fix f)) => Show (Fix f) where
>   show (InF x) = "InF (" ++ show x ++ ")"

> rec :: Functor f => (f v -> v) -> Fix f -> v
> rec m (InF fd) = m
>     (fmap (rec m {- :: Fix f -> v -})
>           (fd {- :: f (Fix f)-})
>      {- :: f v -})

> instance Traversable Id where
>   traverse f (Id x) = Id <$> f x

> instance Traversable (Ko a) where
>   traverse _ (Ko c) = pure (Ko c)

> instance (Traversable p, Traversable q) => Traversable (p :+: q) where
>   traverse f (Le px)  = Le <$> traverse f px
>   traverse f (Ri qx)  = Ri <$> traverse f qx

> instance (Traversable p, Traversable q) => Traversable (p :*: q) where
>   traverse f (px :& qx)  = (:&) <$> traverse f px <*> traverse f qx

> instance Applicative Id where  -- makes fmap from traverse
>   pure = Id
>   Id f <*> Id s = Id (f s)

> instance Monoid c => Applicative (Ko c) where-- makes crush from traverse
>   -- pure :: x -> K c x
>   pure _ = Ko mempty
>   -- (<*>) :: K c (s -> t) -> K c s -> K c t
>   Ko f <*> Ko s = Ko (mappend f s)

> crush :: (Traversable f, Monoid c) => (x -> c) -> f x -> c
> crush m fx = unKo $ traverse (Ko . m) fx

> reduce :: (Traversable f, Monoid c) => f c -> c
> reduce = crush id

> instance Monoid Int where
>   mempty = 0
>   mappend = (+)

> size :: (Functor f, Traversable f) => Fix f -> Int
> size = rec ((1+) . reduce)

> instance HalfZip Id where
>   halfZip (Id x) (Id y) = pure (Id (x,y))

> instance (Eq a) => HalfZip (Ko a) where
>   halfZip (Ko x) (Ko y) | x == y = pure (Ko x)
>   halfZip _ _ = Nothing

> instance (HalfZip p, HalfZip q) => HalfZip (p :+: q) where
>   halfZip (Le x) (Le y) = Le <$> halfZip x y
>   halfZip (Ri x) (Ri y) = Ri <$> halfZip x y
>   halfZip _ _ = Nothing

> instance (HalfZip p, HalfZip q) => HalfZip (p :*: q) where
>   halfZip (x0 :& y0) (x1 :& y1) = (:&) <$> halfZip x0 x1 <*> halfZip y0 y1

>   -- HalfZip xs xs = Just (fmap (\x -> (x,x)) xs)

> infixl 4 $>

> -- | Flipped version of '<$'.
> --
> -- /Since: 4.7.0.0/
> ($>) :: Functor f => f a -> b -> f b
> ($>) = flip (<$)

> void :: Functor f => f a -> f ()
> void = fmap (const ())

Newtype Unwrapping
------------------

> instance Newtype (Id a) a where
>   pack = Id
>   unpack = unId

Applicative Kit
---------------

The `untilA` operator runs its first argument one or more times until
its second argument succeeds, at which point it returns the result. If
the first argument fails, the whole operation fails. If you have
understood `untilA`, it won't take you long to understand `whileA`.

> untilA :: Alternative f => f () -> f a -> f a
> g `untilA` test = g *> try
>     where try = test <|> (g *> try)

> whileA :: Alternative f => f () -> f a -> f a
> g `whileA` test = try
>     where try = test <|> (g *> try)

The `much` operator runs its argument until it fails, then returns the
state of its last success. It is very similar to `many`, except that it
throws away the results.

> much :: Alternative f => f () -> f ()
> much f = (f *> much f) <|> pure ()

Monadic Kit
-----------

> ignore :: Monad m => m a -> m ()
> ignore f = do
>     f
>     return ()
