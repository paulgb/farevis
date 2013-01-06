
d3 = require 'd3'
{Set} = require 'simplesets'

main = ->
  # Click "Time bars" link
  for a in document.getElementsByTagName('a')
    if a.textContent == 'Time bars'
      a.click()

  container = d3.select('#solutionPane td.itaRoundedPaneMain')
  container.select('*').remove()
  container.attr('style', 'height: 500px')
  svg = container.append('svg:svg')

  solutions = ita.flightsPage.flightsPanel.flightList.summary.solutions

  origins = new Set()
  destinations = new Set()
  intermediates = new Set()

  flightTimes = []

  for solution in solutions
    legs = solution.itinerary.slices[0].legs
    for leg, index in legs
      flightTimes.push(new Date(leg.departure))
      flightTimes.push(new Date(leg.arrival))
      if index == 0
        origins.add(leg.origin)
      if index == legs.length - 1
        destinations.add(leg.destination)
      else
        intermediates.add(leg.destination)

  allAirports = origins.array().concat(intermediates.array()).concat(destinations.array())

  airportScale = d3.scale.ordinal()
  airportScale.domain(allAirports)
  airportScale.rangeBands([10, 300])
  window.airportScale = airportScale

  dateScale = d3.time.scale()
  dateScale.domain([d3.min(flightTimes), d3.max(flightTimes)])
  dateScale.range([30, 500])
  window.dateScale = dateScale

  pair = (x, y) ->
    "#{x},#{y}"

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
      path.push(pair(endX, endY))
      path.push('L')
    path.pop()
    path.join(' ')
    
  svg.selectAll('text')
     .data(allAirports)
     .enter()
     .append('text')
       .attr('x', 0)
       .attr('y', airportScale)
       .style('dominant-baseline', 'middle')
       .text((x) -> x)

  svg.selectAll('path')
     .data(solutions)
     .enter()
     .append('path')
       .attr('d', toLine)
       .style('stroke-width', 2)
       .style('stroke', 'red')
       .style('fill', 'none')

main()

