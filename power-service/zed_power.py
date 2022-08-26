import sys

if __name__ == '__main__':
	try:
		if sys.argv[1] == 'up':
			print("Stingray power: Start power up sequence")
		elif sys.argv[1] == 'partial':
			print("Stingray power: Start partial power up sequence")
		elif sys.argv[1] == 'down':
			print("Stingray power: Start power down sequence")
		else:
			print('Stingray power: Please specify "up", "partial" or "down" option')
	except IndexError:
		print('Stingray power: Please specify "up" or "down" option')
