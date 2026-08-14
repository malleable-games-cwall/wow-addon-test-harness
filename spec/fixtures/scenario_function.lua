-- Scenario expressed as a function that receives the session.
return function(session)
  session:slash("/sample scripted")
  session:setCombat(true)
  session:advance(1)
  session:setCombat(false)
end
