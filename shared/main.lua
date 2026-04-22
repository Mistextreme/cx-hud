-- ESX-Legacy shared initialisation anchor for cx-hud.
-- @es_extended/imports.lua (loaded before this file) populates the global ESX
-- via the esx:getSharedObject callback. This file provides a defensive fallback
-- for edge cases where that callback has not yet fired, and acts as the correct
-- load-order boundary so client/server scripts can safely reference ESX.

if ESX == nil then
    TriggerEvent('esx:getSharedObject', function(obj)
        ESX = obj
    end)
end