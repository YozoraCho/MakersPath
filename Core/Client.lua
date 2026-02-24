local _, MakersPath = ...
MakersPath = MakersPath or {}

local pid = WOW_PROJECT_ID

MakersPath.client = {
  projectId = pid,
  isEra = (pid == WOW_PROJECT_CLASSIC),
  isTBC = (pid == WOW_PROJECT_BURNING_CRUSADE_CLASSIC),
}

MakersPath.features = MakersPath.features or {}
MakersPath.features.jewelcrafting = MakersPath.client.isTBC
MakersPath.features.sockets       = MakersPath.client.isTBC
MakersPath.features.ratings       = MakersPath.client.isTBC