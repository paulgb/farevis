
d3 = require 'd3'
{Set} = require 'simplesets'
moment = require 'moment'

main = ->
  # Click "Time bars" link
  for a in document.getElementsByTagName('a')
    if a.textContent == 'Time bars'
      a.click()

  container = d3.select('#solutionPane td.itaRoundedPaneMain')
  container.select('*').remove()
  container.attr('style', 'height: 600px')
  svg = container.append('svg:svg')
  width = svg[0][0].offsetWidth
  height = svg[0][0].offsetHeight

  solutions = ita.flightsPage.flightsPanel.flightList.summary.solutions

  origins = new Set()
  destinations = new Set()
  intermediates = new Set()

  flightTimes = []
  airportTimezones = {}

  for solution in solutions
    legs = solution.itinerary.slices[0].legs
    for leg, index in legs
      flightTimes.push(new Date(leg.departure))
      flightTimes.push(new Date(leg.arrival))
      
      airportTimezones[leg.origin] = ita.isoOffsetInMinutes(leg.departure)
      airportTimezones[leg.destination] = ita.isoOffsetInMinutes(leg.arrival)
      if index == 0
        origins.add(leg.origin)
      else
        intermediates.add(leg.origin)
      if index == legs.length - 1
        destinations.add(leg.destination)
      else
        intermediates.add(leg.destination)

  intermediatesA = intermediates.array().sort((a, b) -> airportTimezones[b] - airportTimezones[a])
  console.log intermediatesA

  window.airportTimezones = airportTimezones
  allAirports = origins.array().concat(intermediatesA).concat(destinations.array())

  airportScale = d3.scale.ordinal()
  airportScale.domain(allAirports)
  airportScale.rangeBands([20, height])
  window.airportScale = airportScale

  dateScale = d3.time.scale()
  dateScale.domain([d3.min(flightTimes), d3.max(flightTimes)])
  dateScale.range([40, width])
  window.dateScale = dateScale

  pair = (x, y) ->
    "#{x},#{y}"

  carrierToColorMap = ita.flightsPage.matrix.stopCarrierMatrix.carrierToColorMap

  toLine = (solution) ->
    itinerary = solution.itinerary
    legs = itinerary.slices[0].legs
    startX = dateScale(legs[0].departure)
    startY = airportScale(legs[0].origin)
    path = ['M']
    for leg in legs
      startX = dateScale(new Date(leg.departure))
      endX = dateScale(new Date(leg.arrival))
      startY = airportScale(leg.origin)
      endY = airportScale(leg.destination)

      path.push(pair(startX, startY))
      path.push('C')
      path.push(pair((startX + endX) / 2, startY))
      path.push(pair((startX + endX) / 2, endY))
      #path.push(pair(endX, startY))
      #path.push(pair(startX, endY))

      path.push(pair(endX, endY))
      path.push('L')
    path.pop()
    path.join(' ')

  svg.append('rect')
     .attr('height', '100%')
     .attr('width', '100%')
     .attr('fill', 'white')
    
  svg.selectAll('text.yAxis')
     .data(allAirports)
     .enter()
     .append('text')
       .attr('x', 10)
       .attr('y', airportScale)
       .style('dominant-baseline', 'middle')
       .text((x) -> x)

  svg.selectAll('g.timeGroup')
     .data(allAirports)
     .enter()
     .append('g')
       .attr('transform', (x) -> "translate(0, #{airportScale(x)})")
       .selectAll('text')
       .data(dateScale.ticks(10))
       .enter()
       .append('text')
         .attr('x', dateScale)
         .style('dominant-baseline', 'middle')
         .text((x) -> moment(x).format('HH:mm'))

  flightPaths = svg.selectAll('path.flight')
     .data(solutions)
     .enter()

  ###
  flightPaths
     .append('path')
       .attr('d', toLine)
       .style('stroke-width', 8)
       .style('stroke', 'white')
       .style('fill', 'none')
  ###

  flightPaths
     .append('path')
       .attr('d', toLine)
       .style('stroke-width', 4)
       .style('stroke', (x) -> carrierToColorMap[x.itinerary.slices[0].legs[0].carrier])
       .style('fill', 'none')

main()

