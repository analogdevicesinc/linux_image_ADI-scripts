import sys
import subprocess

MODEL_PATH = '/sys/firmware/devicetree/base/model'

def read_file(path):
	with open(path, 'r') as file:
		return file.read()

def read_model_file():
	# Device tree strings are null-terminated
	return read_file(MODEL_PATH).strip('\0')

def run_py_script(path, args):
	subprocess.run(['python3', path, *args])

if __name__ == '__main__':
	model = read_model_file()

	print(f'Found model name: {model}')

	SYSTEMD_PATH = '/usr/share/systemd'

	STINGRAY_POWER_PATH = f'{SYSTEMD_PATH}/stingray_power.py'
	STINGRAY_V1_0_MODEL = 'Stingray ZynqMP ZCU102 Rev1.0'

	ZED_POWER_PATH = f'{SYSTEMD_PATH}/zed_power.py'
	ZED_MODEL = 'Xilinx Zynq ZED'

	if model == STINGRAY_V1_0_MODEL:
		run_py_script(STINGRAY_POWER_PATH, [sys.argv[1]])
	elif model == ZED_MODEL:
		run_py_script(ZED_POWER_PATH, [sys.argv[1]])
