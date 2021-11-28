import pygame
try:
    import RPi.GPIO as GPIO
    has_pi = True
except:
    print('no rpi found')
    has_pi = False
from time import sleep
HBRIDGE_1_PIN=11
HBRIDGE_2_PIN=13
HBRIDGE_3_PIN=16
HBRIDGE_4_PIN=15

def go_forward():
    if has_pi:
        GPIO.output(HBRIDGE_1_PIN, True)
        GPIO.output(HBRIDGE_2_PIN, False)
        GPIO.output(HBRIDGE_3_PIN, True)
        GPIO.output(HBRIDGE_4_PIN, False)
    print(f'going forward, relay 1 True, relay 2 False,relay 3 True,relay 4 False')

def go_backward():
    if has_pi:
        GPIO.output(HBRIDGE_1_PIN, False)
        GPIO.output(HBRIDGE_2_PIN, True)
        GPIO.output(HBRIDGE_3_PIN, False)
        GPIO.output(HBRIDGE_4_PIN, True)
    print(f'going backward, relay 1 False, relay 2 True,relay 3 False,relay 4 True')

def stop_moving():
    if has_pi:
        GPIO.output(HBRIDGE_1_PIN, False)
        GPIO.output(HBRIDGE_2_PIN, False)
        GPIO.output(HBRIDGE_3_PIN, False)
        GPIO.output(HBRIDGE_4_PIN, False)
    print(f'stopping, relay 1 False, relay 2 False,relay 3 False,relay 4 False')

if has_pi:
    GPIO.setmode(GPIO.BOARD)
    GPIO.setup(HBRIDGE_1_PIN, GPIO.OUT)
    GPIO.setup(HBRIDGE_2_PIN, GPIO.OUT)
    GPIO.setup(HBRIDGE_3_PIN, GPIO.OUT)
    GPIO.setup(HBRIDGE_4_PIN, GPIO.OUT)
    while True:
        go_forward()
        sleep(2)
        go_backward()
        sleep(2)
        stop_moving()
        sleep(2)
