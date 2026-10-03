-- roteiro: PLAN (arquivo lua) devolve {acts={{f,port,field,n}}, snaps={{a,b,step}}, stop=N, ram="arq"}
local plan = dofile(os.getenv("PLAN"))
local ports = manager.machine.ioport.ports
local f = 0
local held = {}
local ramf = plan.ram and io.open(plan.ram, "wb")
local cpu = manager.machine.devices[":maincpu"]
local data = cpu.spaces["data"]
-- espelho do i8244 (VDC) e da RAM externa, montado pelas escritas MOVX
VDC = {} XRAM = {} for i=0,255 do VDC[i]=0 XRAM[i]=0 end
VLOG = plan.vlog and io.open(plan.vlog, "wb")
local iosp = cpu.spaces["io"]
TAP = iosp:install_write_tap(0, 0xff, "vdc", function(off, d, mask)
  local p1 = cpu.state["P1"].value
  if (p1 & 0x50) == 0 then XRAM[off & 0xff] = d
  elseif (p1 & 0x08) == 0 then VDC[off & 0xff] = d
    if VLOG and (off & 0xff) >= 0xA0 and (off & 0xff) <= 0xAA then VLOG:write(string.char(255, (off & 0xff), d)) end
  end
end)
local function fld(p, n) return ports[p].fields[n] end
emu.register_frame_done(function()
  f = f + 1
  for _, a in ipairs(plan.acts) do
    if a[1] == f then fld(a[2], a[3]):set_value(1); held[#held+1] = {f + a[4], a[2], a[3]} end
  end
  for i = #held, 1, -1 do
    local h = held[i]
    if h[1] == f then fld(h[2], h[3]):set_value(0); table.remove(held, i) end
  end
  if plan.hook then local ok, e = pcall(plan.hook, f, data, fld, VDC) if not ok then print("ERRO", e) manager.machine:exit() end end
  for _, s in ipairs(plan.snaps) do
    if f >= s[1] and f <= s[2] and (f - s[1]) % s[3] == 0 then manager.machine.video:snapshot() end
  end
  if VLOG then VLOG:write(string.char(254)) end
  if plan.vdc then local t = {} for i = 0, 255 do t[#t+1] = string.char(VDC[i]) end for i = 0, 255 do t[#t+1] = string.char(XRAM[i]) end plan.vdcf = plan.vdcf or io.open(plan.vdc, "wb") plan.vdcf:write(table.concat(t)) end
  if ramf then local t = {} for i = 0, 63 do t[#t+1] = string.char(data:read_u8(i)) end ramf:write(table.concat(t)) end
  if f % 100 == 0 then local pf = io.open("prog.txt","w") pf:write(f) pf:close() end
  if f >= plan.stop then if plan.vdcf then plan.vdcf:close() end if VLOG then VLOG:close() end if ramf then ramf:close() end manager.machine:exit() end
end)
