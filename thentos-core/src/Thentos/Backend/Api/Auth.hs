{-# LANGUAGE FlexibleContexts                         #-}
{-# LANGUAGE FlexibleInstances                        #-}
{-# LANGUAGE MultiParamTypeClasses                    #-}
{-# LANGUAGE ScopedTypeVariables                      #-}
{-# LANGUAGE TypeFamilies                             #-}
{-# LANGUAGE TypeOperators                            #-}

-- | Authentication via 'ThentosSessionToken'.
--
-- A LESS RELEVANT OBSERVATION: It would be nice if we could provide this function:
--
-- >>> thentosAuth :: ActionState
-- >>>             -> ServerT api (Action)
-- >>>             -> Maybe ThentosSessionToken
-- >>>             -> Server api
-- >>> thentosAuth actionState _api mTok = enter (enterAction actionState mTok) _api
--
-- because then here we could write:
--
-- >>> api :: ActionState -> Server (ThentosAuth :> MyApi)
-- >>> api = (`thentosAuth` myApi)
--
-- But the signature of `thentosAuth` requires injectivity of `ServerT` (`api` needs to be inferred
-- from `ServerT api (Action)`).  ghc-7.12 may help (see
-- https://ghc.haskell.org/trac/ghc/wiki/InjectiveTypeFamilies), or it may not: Even if injective
-- type families are supported, `ServerT` may not be injective in some particular type that this
-- function is called with.
--
-- So instead, you will have to write something like this:
--
-- >>> api :: ActionState -> Server (ThentosAuth :> MyApi)
-- >>> api actionState mTok = enter (enterAction actionState mTok) myApi
module Thentos.Backend.Api.Auth where

import Control.Lens ((&), (<>~))
import Data.CaseInsensitive (foldedCase)
import Data.Proxy (Proxy(Proxy))
import Data.String.Conversions (cs)
import Data.Text (empty)
import Servant.API ((:>))
import Servant.Server (HasServer, ServerT, route)
import Servant.Server.Internal (Router'(WithRequest), passToServer)
import Servant.Utils.Links (HasLink(MkLink, toLink))

import qualified Servant.Foreign as F

import Thentos.Backend.Core
import Thentos.Types


data ThentosAuth

instance HasServer sub => HasServer (ThentosAuth :> sub) where
  type ServerT (ThentosAuth :> sub) m = Maybe ThentosSessionToken -> ServerT sub m
  route Proxy sub = WithRequest $ \ request -> route (Proxy :: Proxy sub)
      (passToServer sub $ lookupThentosHeaderSession renderThentosHeaderName request)

instance HasLink sub => HasLink (ThentosAuth :> sub) where
    type MkLink (ThentosAuth :> sub) = MkLink sub
    toLink _ = toLink (Proxy :: Proxy sub)

instance F.HasForeign F.NoTypes sub => F.HasForeign F.NoTypes (ThentosAuth :> sub) where
    type Foreign (ThentosAuth :> sub) = F.Foreign sub
    foreignFor plang Proxy req = F.foreignFor plang (Proxy :: Proxy sub) $ req
            & F.reqHeaders <>~
                [F.HeaderArg (cs . foldedCase $ renderThentosHeaderName ThentosHeaderSession, empty)]
