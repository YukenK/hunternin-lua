function math.clamp(n, min, max)
	return math.max(min, math.min(n, max))
end
function math.round_up(n, round) -- Find the nearest upwards round, get the amount you'd multiple round by to get to that. ... is that even English?
	return bit.band(n + (round - 1), bit.bnot(round - 1))
end
