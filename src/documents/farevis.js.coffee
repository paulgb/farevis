
d3 = require 'd3'
#{Set} = require 'simplesets'
moment = require 'moment'

class Flight
  constructor: (@legs, @price, @startTime, @endTime, @index) ->

  superior: (otherFlight) ->
    # return true iff this flight is superior to otherFlight
    
    # is otherFlight superior to this flight?
    if otherFlight.startTime > @startTime
      return false
    if otherFlight.endTime < @endTime
      return false
    if otherFlight.price < @price
      return false

    # Is this flight superior to otherFlight?
    if otherFlight.startTime < @startTime
      return true
    if otherFlight.endTime > @endTime
      return true
    if otherFlight.price > @price
      return true

    # Arbitrary Tiebreaker
    if otherFlight.index <= @index
      return false
    return true

class Leg
  constructor: (@origin, @destination, @departure, @arrival, @carrier) ->

class Airport
  constructor: (@code, @city, @timezone) ->

  setTz: (@tz) ->
    @city.tz = @tz

class City
  constructor: (@code, @name) ->

class Carrier
  constructor: (@code, @name, @color) ->

class Gate
  constructor: (@code, @airport) ->

get_data = (ita) ->
  itaData = ita.flightsPage.flightsPanel.flightList
  carrierToColorMap = ita.flightsPage.matrix.stopCarrierMatrix.carrierToColorMap
  isoOffsetInMinutes = ita.isoOffsetInMinutes

  cities = {}
  airports = {}
  flights = []
  carriers = {}

  # Load City data
  for code, itaCity of itaData.data.cities
    city = new City(code, itaCity.name)
    cities[code] = city

  # Load Airport data
  for code, itaAirport of itaData.data.airports
    airport = new Airport(code, cities[itaAirport.city],
      itaAirport.name)
    airports[code] = airport

  # Load Carrier Data
  for code, itaCarrier of itaData.data.carriers
    carrier = new Carrier(code, itaCarrier.shortName,
      carrierToColorMap[code])
    carriers[code] = carrier

  # Load Flight Data
  for solution, index in itaData.summary.solutions
    legs = []
    price = parseFloat(solution.itinerary.pricings[0].displayPrice.substring(3))
    itaLegs = solution.itinerary.slices[0].legs
    startTime = moment(itaLegs[0].departure)
    endTime = moment(itaLegs[itaLegs.length - 1].arrival)
    for itaLeg in itaLegs
      airports[itaLeg.origin].setTz(isoOffsetInMinutes(itaLeg.departure))
      airports[itaLeg.destination].setTz(isoOffsetInMinutes(itaLeg.arrival))
      leg = new Leg(airports[itaLeg.origin],
                    airports[itaLeg.destination],
                    moment(itaLeg.departure),
                    moment(itaLeg.arrival),
                    carriers[itaLeg.carrier])
      legs.push(leg)
    flight = new Flight(legs, price, startTime, endTime, index)
    flights.push(flight)

  # Get rid of duplicate and inferior flights
  trimmed_flights = []
  for flight1 in flights
    trim = false
    for flight2 in flights
      if flight2.superior(flight1)
        trim = true
        break
    if not trim
      trimmed_flights.push(flight1)
  flights = trimmed_flights

  return {cities, airports, flights, carriers}

main = ->
  console.log get_data(ita)

main()

