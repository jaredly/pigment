Managing Entries in a Proof Context
===================================

> {-# LANGUAGE FlexibleInstances, TypeOperators, TypeSynonymInstances,
>              GADTs, RankNTypes, PatternSynonyms #-}

> module ProofState.Edition.Entries where

> import Data.Traversable
> import NameSupply.NameSupply
> import ProofState.Structure.Developments
> import ProofState.Edition.ProofContext
> import Evidences.Tm
> import Kit.BwdFwd

Manipulating the `CurrentEntry`

As with entries in Section [ProofState.Structure.Entries](#ProofState.Structure.Entries), we need
some kit operating on any kind of `CurrentEntry`. So far, this is
restricted to getting its name:

> currentEntryName :: CurrentEntry -> Name
> currentEntryName  (CDefinition _ (n := _) _ _ _ _) = n
> currentEntryName  (CModule n _ _)                  = n

There is an obvious (forgetful) map from entry (Definition or Module) to
a current entry:

> mkCurrentEntry :: Traversable f => Entry f -> CurrentEntry
> mkCurrentEntry (EDEF ref xn dkind _ ty a meta)
>     = CDefinition dkind ref xn ty a meta
> mkCurrentEntry (EModule n _ p meta)
>     = CModule n p meta

From Above to Below, and back

The `aboveEntries` and `belowEntries` give a certain twist to the visit
of a `Layer`: on one hand, `aboveEntries` go `Bwd`; on the other hand,
`belowEntries` go `Fwd` with news. Therefore, when moving the cursor, we
sometimes need to change the structure that contains entries.

We define such ‘rearranging' function by mutual induction on `Entry f`
and `Dev f`:

> rearrangeEntry ::  (Traversable f, Traversable g) =>
>                    (forall a. f a -> g a) -> Entry f -> Entry g
> rearrangeEntry h (EPARAM ref xn k ty a meta)
>     = EPARAM ref xn k ty a meta
> rearrangeEntry h (EDEF ref xn k dev ty a meta)
>     = EDEF ref xn k (rearrangeDev h dev) ty a meta
> rearrangeEntry h (EModule n d p meta)
>     = EModule n (rearrangeDev h d) p meta

> rearrangeDev :: (Traversable f, Traversable g) =>
>     (forall a. f a -> g a) -> Dev f -> Dev g
> rearrangeDev h d@(Dev {devEntries=xs}) = d{devEntries=rearrangeEntries h xs}
>     where  rearrangeEntries ::  (Traversable f, Traversable g) =>
>                                 (forall a. f a -> g a) ->
>                                 f (Entry f) -> g (Entry g)
>            rearrangeEntries h xs = h (fmap (rearrangeEntry h) xs)

Hence, we can change the carrier of `Entry` from `Bwd` to `Fwd` or a
variation thereof:

> reverseEntry :: Entry Bwd -> Entry NewsyFwd
> reverseEntry = rearrangeEntry (NF . fmap Right . (<>> F0))

> reverseEntries :: Fwd (Entry Bwd) -> NewsyEntries
> reverseEntries es = NF $ fmap (Right . reverseEntry) es

Or we can change the carrier of a whole `Dev` from `Bwd` to `Fwd`:

> reverseDev :: Dev Bwd -> Dev Fwd
> reverseDev = rearrangeDev (<>> F0)
