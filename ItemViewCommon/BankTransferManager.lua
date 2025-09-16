---@class addonTableBaganator
local addonTable = select(2, ...)

addonTable.BankTransferManagerMixin = {}

function addonTable.BankTransferManagerMixin:OnLoad()
  if not C_Bank then
    return
  end
  self.allocatedSlots = {}
  self.queue = {}
end

function addonTable.BankTransferManagerMixin:Queue(bagID, slotID)
  if not C_Bank or not BankPanel:IsShown() then
    return
  end
  ClearCursor()

  local location = {bagID = bagID, slotIndex = slotID}
  if not C_Item.DoesItemExist(location) or C_Item.IsLocked(location) then
    return
  end

  local bagIndex = tIndexOf(Syndicator.Constants.AllBagIndexes, bagID)
  local source = Syndicator.Search.GetBaseInfo(Syndicator.API.GetCharacter(Syndicator.API.GetCurrentCharacter()).bags[bagIndex][slotID])

  if not source.itemID then
    return
  end

  local targets = addonTable.Transfers.GetCurrentBankSlots()
  local stackLimit = C_Item.GetItemMaxStackSizeByID(source.itemID)

  local matches = {}
  for index, item in ipairs(targets) do
    if (self.allocatedSlots[item.bagID] == nil or not self.allocatedSlots[item.bagID][item.slotID]) and (
      item.itemID == nil or (item.itemID == source.itemID and item.itemCount < stackLimit)
    ) then
      match = item
      break
    end
  end
  if match then
    self.allocatedSlots[match.bagID] = self.allocatedSlots[match.bagID] or {}
    self.allocatedSlots[match.bagID][match.slotID] = true

    C_Container.PickupContainerItem(bagID, slotID)
    C_Container.PickupContainerItem(match.bagID, match.slotID)

    Syndicator.CallbackRegistry:RegisterCallback("BagCacheUpdate", self.BagUpdate, self)
    Syndicator.CallbackRegistry:RegisterCallback("WarbandBankCacheUpdate", self.BagUpdate, self)

    if match.itemCount and match.itemCount + source.itemCount > stackLimit then
      table.insert(self.queue, {bagID = bagID, slotID = slotID})
    end
  else
    UIErrorsFrame:AddMessage(addonTable.Locales.CANNOT_MOVE_ITEMS_AS_NO_SPACE_LEFT, 1.0, 0.1, 0.1, 1.0)
  end
end

function addonTable.BankTransferManagerMixin:BagUpdate()
  if not BankPanel:IsShown() then
    self.allocatedSlots = {}
  end
  if #self.queue > 0 then
    local item = table.remove(self.queue)
    self:Queue(item.bagID, item.slotID)
  end
  for bagID, slots in pairs(self.allocatedSlots) do
    for slotID, state in pairs(slots) do
      if C_Item.DoesItemExist({bagID = bagID, slotIndex = slotID}) then
        slots[slotID] = nil
      end
    end
    if next(slots) == nil then
      self.allocatedSlots[bagID] = nil
    end
  end
  if next(self.allocatedSlots) == nil then
    Syndicator.CallbackRegistry:UnregisterCallback("BagCacheUpdate", self)
    Syndicator.CallbackRegistry:UnregisterCallback("WarbandBankCacheUpdate", self)
  end
end
