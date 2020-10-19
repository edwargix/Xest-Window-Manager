module Tiler.ParentChild where

import Graphics.X11.Types
import Standard

-- | A child parent relationship between two windows.
data ParentChild = ParentChild {getParent :: Window, getChild :: Window}
  deriving (Show)

-- | Is some window in the family?
inParentChild :: Window -> ParentChild -> Bool
inParentChild win (ParentChild ww ww') = win == ww || win == ww'

-- | If either the child or the parent are equal, then the whole type
--  is equal. TODO
instance Eq ParentChild where
  (ParentChild a b) == (ParentChild a' b') = a == a' || b == b'
