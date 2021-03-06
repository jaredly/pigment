Generic name supplier
=====================

> {-# LANGUAGE TypeOperators, GADTs, RankNTypes,
>     TypeSynonymInstances, FlexibleInstances, ScopedTypeVariables,
>     MultiParamTypeClasses, FlexibleContexts, UndecidableInstances #-}

> module NameSupply.NameSupplier where

> import Control.Applicative
> import Control.Monad.Reader

> import Control.Error

> import NameSupply.NameSupply
> import Evidences.Tm

The `NameSupplier` type-class aims at giving the ability to use the
`NameSupply` in a safe way. There is trade-off here between ease of
implementation and safety. As it stands now, this version offers
moderate safety but is easy to use. Ideally, we would like most of the
code to use `NameSupplier` instead of manipulating the `NameSupply`
explicitly.

So, what does `NameSupplier` offer?

> class (Applicative m, Monad m) => NameSupplier m where

First, `freshRef` enables the safe creation of fresh names inside the
structure: it is provided with an informative name, the variable type,
and a *body* consuming that free variable. It returns the body with the
free variable filled in, while maintaining the coherency of the
namespace.

>     freshRef    :: (String :<: TY) -> (REF -> m t) -> m t

Similarly, `forkNSupply` is a safe wrapper around `freshName` and
`freshNSpace`: `forkNSupply subname child dad` runs the `child` with the
current namespace extended with `subname`, then, `dad` gets the result
of `child`'s work and can go ahead with a fresh variable index.

>     forkNSupply  :: String -> m s -> (s -> m t) -> m t

Finally, we have an `askNSupply` operation, to *read* the current
`NameSupply`. This was a difficult choice: we give up the read-only
access to the `NameSupply`, allowing the code to use it in potentially
nasty ways. This operation has been motivated by `equal` that calls into
`exQuote`. `exQuote` on a paramater uses and abuses some invariants of
the name fabric, hence needs direct access to the `NameSupply`
structure.

>     askNSupply   :: m NameSupply

Because of the presence of `askNSupply`, we have here a kind of Reader
monad on steroids. This might not be true forever; we can hope to
replace `askNSupply` by a finer grained mechanism.

Sometimes you want a fresh value rather than a reference:

> fresh :: NameSupplier m => (String :<: TY) -> (VAL -> m t) -> m t
> fresh xty f = freshRef xty (f . pval)

`(->) NameSupply` is a `NameSupplier`
-------------------------------------

To illustrate the implementation of a `NameSupplier`, we implement the
`NameSupply` Reader monad:

> instance NameSupplier ((->) NameSupply) where
>     freshRef (x :<: ty) f r = f (mkName r x := DECL :<: ty) (freshName r)
>     forkNSupply s child dad nsupply = (dad . child)
>         (freshNSpace nsupply s)
>         (freshName nsupply)
>     askNSupply r = r

`ReaderT NameSupply` is a `NameSupplier`
----------------------------------------

Once we have a `NameSupplier` for the `NameSupply` Reader monad, we can
actually get it for any `ReaderT NameSupply`. This is as simple as:

> instance (Monad m, Applicative m) => NameSupplier (ReaderT NameSupply m) where
>     freshRef st body = do
>         nsupply <- ask
>         lift $ freshRef st (runReaderT . body) nsupply
>     forkNSupply s child dad = do
>         c <- local (`freshNSpace` s) child
>         local freshName (dad c)
>     askNSupply = ask

Similarly, we can lift a `NameSupplier` to `EitherT`.

> instance (Monad m, Applicative m) => NameSupplier (EitherT f (ReaderT NameSupply m)) where
>     freshRef (x :<: ty) f = do
>         nsupply <- askNSupply
>         let generatedName = mkName nsupply x := DECL :<: ty
>         f generatedName
>
>     forkNSupply s child dad = do
>         c <- local (`freshNSpace` s) child
>         local freshName (dad c)
>     askNSupply = ask

      freshRef    :: (String :<: TY) -> (REF -> m t) -> m t
      forkNSupply  :: String -> m s -> (s -> m t) -> m t
      askNSupply   :: m NameSupply

<a name="NameSupply.NameSupplier.check-monad">The `Check` monad is a `NameSupplier`</a>
-------------------------------------

One such example is the `Check` monad:

> type Check e = ReaderT NameSupply (Either (StackError e))

> instance ErrorStack (Check e) e where
>     throwStack = lift . Left

That is, a Reader of `NameSupply` on top of an Error of `StackError`.
Running a type-checking process is therefore a simple `runReader`
operation:

> typeCheck :: Check e a -> NameSupply -> Either (StackError e) a
> typeCheck = runReaderT
