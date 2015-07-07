{-# LANGUAGE FlexibleContexts     #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE TupleSections        #-}
{-# LANGUAGE TypeOperators        #-}

module Thentos.Transaction.Core
  ( ThentosUpdate
  , ThentosQuery
  , liftThentosQuery
  , runThentosUpdate
  , runThentosQuery
  , polyUpdate
  , polyQuery
  ) where

import Control.Applicative ((<$>))
import Control.Lens ((^.), (%%~))
import Control.Monad.Identity (Identity(Identity), runIdentity)
import Control.Monad.Reader (ReaderT(ReaderT), runReaderT, ask)
import Control.Monad.State (StateT(StateT), runStateT, get, put)
import Control.Monad.Trans.Either (EitherT(EitherT), runEitherT)
import Data.Acid (Update, Query)
import Data.EitherR (fmapL)

import Thentos.Types


-- * types

type ThentosUpdate db a = EitherT (ThentosError db) (StateT  db Identity) a
type ThentosQuery  db a = EitherT (ThentosError db) (ReaderT db Identity) a

-- FUTURE WORK: make primed types newtypes rather than type synonyms, and provide a generic monad
-- instance.  (how does that work?)


-- * plumbing

-- | 'liftQuery' for 'ThentosUpdate' and 'ThentosUpdate''.
liftThentosQuery :: ThentosQuery db a -> ThentosUpdate db a
liftThentosQuery thentosQuery = EitherT . StateT $ \ state ->
    (, state) <$> runEitherT thentosQuery `runReaderT` state


-- | Push 'ThentosUpdate' event down to acid-state's own 'Update'.  Errors are returned as 'Left'
-- values in an 'Either'.  See also:
--
-- - http://www.reddit.com/r/haskell/comments/2re0da/error_handling_in_acidstate/
-- - http://petterbergman.se/aciderror.html.en
-- - http://acid-state.seize.it/Error%20Scenarios
-- - https://github.com/acid-state/acid-state/pull/38
runThentosUpdate :: ThentosUpdate db a -> Update db (Either (ThentosError db) a)
runThentosUpdate action = do
    state <- get
    case runIdentity $ runStateT (runEitherT action) state of
        (Left err,     _)      ->                return $ Left  err
        (Right result, state') -> put state' >> (return $ Right result)

-- | 'runThentosUpdate' for 'ThentosQuery' and 'ThentosQuery''
runThentosQuery :: ThentosQuery db a -> Query db (Either (ThentosError db) a)
runThentosQuery action = runIdentity . runReaderT (runEitherT action) <$> ask


-- | Turn an update transaction on a db into one on any extending db.  See also 'polyQuery'.
--
-- FUTURE WORK: shouldn't there be a way to do both cases with one function @poly@?  (same goes for
-- 'runThentos*' above, as a matter of fact).
polyUpdate :: forall a db1 db2 . (db2 `Extends` db1) => ThentosUpdate db1 a -> ThentosUpdate db2 a
polyUpdate upd = EitherT . StateT $ Identity . (focus %%~ bare)
  where
    bare :: db1 -> (Either (ThentosError db2) a, db1)
    bare = runIdentity . runStateT (fmapL asDBThentosError <$> runEitherT upd)

-- | Turn a query transaction on a db on any extending db.  See also 'polyUpdate'.
polyQuery :: forall a db1 db2 . (db2 `Extends` db1) => ThentosQuery db1 a -> ThentosQuery db2 a
polyQuery qry = EitherT . ReaderT $ \ (state :: db2) ->
    fmapL asDBThentosError <$> runEitherT qry `runReaderT` (state ^. focus)
