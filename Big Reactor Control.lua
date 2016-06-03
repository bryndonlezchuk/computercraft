--Big Reactors Control Program
--Bryndon Lezchuk <90littlegreenmen@gmail.com>

--Some code inspiration came from similar
--programs by:
--Emily Backes <lucca@accela.net>
--pastebin.com/uALkzjWt
--and Direwolf20
--pastebin.com/4qNyaPav
--pastebin.com/XBbMUYNn

--This version only works with 1 reactor and 
--1 turbine, though it is written to be 
--expanded upon.

--Must be ran from the top level directory /
--This is where config.txt gets saved


--Outputs text in red
function errorprint(txt)
  term.setTextColor(colors.red)
  print(txt)
  term.setTextColor(colors.white)
end


--Outputs the given text then returns
--true or false given the user input
function yesno(txt)
  print(txt.." (y/n)")
  local input = read()
  if input=="y" then
    return true
  elseif input=="n" then
    return false
  else
    errorprint("Please use 'y' or 'n'")
    return yesno(txt)
  end
end


--Checks for the config.txt file
--Returns true if file exists
--Returns true if setup ran
--Returns false if setup was not ran
function chkconfig()
  if not fs.exists("config.txt") then
    if yesno("Configuration not found, would you like to run setup?")
    then
      setup()
      return true
    else
      return false
    end
  else
    return true
  end
end


--loads in config settings from config.txt
function loadconfig()
  local file = fs.open("config.txt","r")
  local data = file.readAll()
  file.close()
  return textutils.unserialize(data)
end


--saves configs to config.txt
function saveconfig()
  local file = fs.open("config.txt","w")
  file.write(textutils.serialize(config))
  file.close()
end


--Gets config settings from user and saves
--them to config.txt
function setup()

  print("This system can be turned on and off by either a redstone signal or via networked capacitors. For redstone, set this field to 0, otherwise how many capacitors are attached to the network?")
  config.numcap = read()
  
  if config.numcap == "0" then
    config.control = "rs"
    print("What side will the redstone signal come from?")
    config.rside = read()
    if yesno("Will the redstone input be bundled?") then
      print("What bundle color will the signal use?")
      config.rcolor = read()
    end
  else
    config.control = "network"
    print("At what power capacity should Reactor/Turbine shut off?")
    config.powermax = read()
    print("How low should the capacity be to turn on Reactor/Turbine?")
    config.powermin = read()
  end
  
  saveconfig()
end


--Gets devices from the network given the type
--and returns them in a table
function getdev(type)
  local dev
  local key
  local d = {} --table of the specified device type
  local wrapped = {}
  
  for key,dev in pairs(peripheral.getNames()) do
    if (peripheral.getType(dev)==type) then
      table.insert(d, dev)
      print("Found Device: "..dev)
    end
  end
  
  for i = 1,#d do
    table.insert(wrapped, peripheral.wrap(d[i]))
    print("Wrapping device "..d[i])
  end
  return wrapped
end


function setRods(reactor, level)
  reactor.setAllControlRodLevels(level)
end


--calculates the optimal fuel rod insertion rate
--to generate the steam needed by turbines
--given a reactor and the steam needed
function getoptfuelrod(r,s)
  local steam99
  local estlevel
  local eststeam
  local steamup = 0
  local steamdown = s * 2

  resetdisplay()
  r.setActive(false)
  while r.getFuelTemperature() > 99 do
    resetdisplay()
    print("Reactor Off-line")
    print("Waiting for reactor to cool off")
    print("Reactor Temp: "..r.getFuelTemperature())
    sleep(1)
  end
  
  setRods(r,99)
  r.setActive(true)
  while r.getHotFluidAmount() > 10000 do
    resetdisplay()
    print("Reactor Online")
    print("Heating reactor up")
    print("Reactor Temp: "..r.getFuelTemperature())
    sleep(1)
  end
  
  for i = 1,5 do
    resetdisplay()
    print("Reactor Online")
    print("Fuel rods set to 99% for "..i.." seconds")
    steam99 = r.getHotFluidProducedLastTick()
    print("Steam produced: "..steam99)
    sleep(1)
  end
  
  estlevel = 100 - math.ceil(s / steam99)
  print("Estimated optimal fuel rod level is "..estlevel)
  --setRods(r,estlevel)
  sleep(3)
  
  local test=true
  while test do
    for i = 1,5 do
      resetdisplay()
      setRods(r,estlevel)
      print("Reactor Online")
      print("Fuel rods set to "..estlevel.."% for "..i.." seconds")
      eststeam = r.getHotFluidProducedLastTick()
      print("Steam produced: "..eststeam)
      sleep(1)
    end
    
    if eststeam > steamdown and eststeam > s and eststeam < steamup then
      test=false
    elseif eststeam > steamup and eststeam > s then
      steamup = eststeam
      estlevel = estlevel + 1
    elseif eststeam < steamdown  then
      steamdown = eststeam
      estlevel = estlevel - 1
    end
  end
  
  print("Optimal Fuel rod insertion is "..estlevel.."%")
  sleep(3)
  return estlevel
end


--Clears the screen and moves cursor
function resetdisplay()
  term.clear()
  term.setCursorPos(1,1)
  
end


--check to see if reactors/turbines should be on
function chkon()
  if config.control == "rs" then
    if rs.testBundledInput(config.rside,config.rcolor) or rs.getInput(config.rside) then
      return true
    else
      return false
    end
  end
  
  if config.control == "network" then
  
  end
end


--The backbone of the program
function main()
  --local r --table of reactors
  --local t --table of turbines
  --local m --table of monitors
  --local c --table of capacitors
  
  local reactor
  local turbine
  local numpassreactor = 0
  local steamneeded = 0
  local steamperreactor = 0
  local optfuelrod = {}
  
  local energystored
  local energymax
  local energypercent
  
  errorprint("Please note, if anything has changed on the network, delete the config.txt")
  print()
  
  if not chkconfig() then
    errorprint("No configuration set, exiting program.")
    return
  else
    config = loadconfig()
  end
  
  r = getdev("BigReactors-Reactor")
  t = getdev("BigReactors-Turbine")
  c = getdev("tile_blockcapacitorbank_name")
  m = getdev("monitor")
    
  sleep(3)
  
  if t~=nil and config.optfuelrod == nil then
    steamneeded = 2000 * #t
    config.optfuelrod = getoptfuelrod(r[1],steamneeded)
    saveconfig()
  end
  
  
  
  --local capacitor = c[1]
  
  --print("test")
  --print(capacitor.getMaxEnergyStored())
  --sleep(2)
  --energymax = capacitor.getMaxEnergyStored()
  --print("System storage capacity is "..energymax)
  
  while true do
    for i,reactor in pairs(r) do
      if reactor.isActivelyCooled() then
        --actively cooled reactor
        resetdisplay()
        --energystored = capacitor.getEnergyStored()
        --energypercent = math.floor((energystored/energymax)*100)
        
        
        
        reactor.setActive(true)
        t[1].setActive(true)
        
        if rs.testBundledInput("top",colors.red) then
          t[1].setInductorEngaged(true)
        else
          t[1].setInductorEngaged(false)
        end
        
        
        --display info
        if reactor.getActive() then
          print("Reactor Online")
        else
          print("Reactor Offline")
        end
        print("Heat: "..reactor.getFuelTemperature())
        print("Steam Produced: "..reactor.getHotFluidProducedLastTick())
        
        
        print()
        if t[1].getActive() then
          print("Turbine Online")
        else
          print("Turbine Offline")
        end
        if t[1].getInductorEngaged() then
          print("Inductors Engaged")
        else
          print("Inductors Disengaged")
        end
        print("Rotor Speed: "..math.floor(t[1].getRotorSpeed()))
        print("Energy Output "..t[1].getEnergyProducedLastTick())
        
        --print("Capacitor max storaged: "..energymax)
        --print("Currenty energy: "..energystored)
        --print("("..energypercent.."% full)")
        
        sleep(1)

        --return --exit here for testing
      else
        --code here for passively cooled reactor
        errorprint("Sorry, code for passively cooled reactors is not yet fully implemented")
		
        reactor.setActive(true)
        if rs.testBundledInput("top",colors.red) then
          reactor.setActive(true)
        else
          reactor.setActive(false)
        end
		
        --return
      end
    end
  end
end


--local args = {...}
local config = {} --table of configs
local r --table of reactors
local t --table of turbines
local m --table of monitors
local c --table of capacitors

main()