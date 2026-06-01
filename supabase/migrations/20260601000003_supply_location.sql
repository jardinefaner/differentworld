-- Supplies Location lens (docs/SUPPLIES.md "Making it more useful" #1).
-- A supply can point at a REAL location from the Locations catalog (Art
-- Barn, Gym, Pool) in addition to its free-text sub-spot ("Cabinet B").
-- This turns Locations + Supplies into two views of one truth: a Location
-- can show its inventory, and Supplies can group "by location".
--
-- `on delete set null` — deleting a location doesn't delete its supplies;
-- they just become unplaced.

alter table public.supplies
  add column if not exists location_id uuid
    references public.locations(id) on delete set null;

create index if not exists supplies_location_idx
  on public.supplies(space_id, location_id);
