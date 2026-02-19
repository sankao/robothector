# Hardware Pinout

## Wiring Diagram

```mermaid
graph LR
    subgraph Pi["Raspberry Pi 4"]
        GPIO26["GPIO 26 (pin 37)"]
        GPIO19["GPIO 19 (pin 35)"]
        GPIO13["GPIO 13 (pin 33)"]
        GPIO6["GPIO 6 (pin 31)"]
        GND["GND (pin 39)"]
        CAM["CSI Camera Port"]
    end

    subgraph L298N["L298N H-Bridge"]
        IN1["IN1"]
        IN2["IN2"]
        IN3["IN3"]
        IN4["IN4"]
        ENA["ENA (jumper)"]
        ENB["ENB (jumper)"]
        OUTA1["OUT1"]
        OUTA2["OUT2"]
        OUTB1["OUT3"]
        OUTB2["OUT4"]
        VIN["12V input"]
        LGND["GND"]
    end

    subgraph Motors
        MA["Motor A (left)"]
        MB["Motor B (right)"]
    end

    subgraph Battery["Battery Pack"]
        BATT["12V"]
    end

    subgraph Camera["Pi Camera Module 3"]
        IMX["IMX708"]
    end

    GPIO26 -- "brown wire" --> IN1
    GPIO19 -- "black wire" --> IN2
    GPIO13 -- "white wire" --> IN3
    GPIO6  -- "grey wire" --> IN4
    GND --- LGND

    OUTA1 --- MA
    OUTA2 --- MA
    OUTB1 --- MB
    OUTB2 --- MB

    BATT --- VIN
    BATT --- LGND

    CAM -- "ribbon cable" --> IMX
```

## Pin Table

| Wire  | GPIO (BCM) | Board Pin | L298N | Motor       |
|-------|------------|-----------|-------|-------------|
| brown | 26         | 37        | IN1   | A (left) +  |
| black | 19         | 35        | IN2   | A (left) -  |
| white | 13         | 33        | IN3   | B (right) + |
| grey  | 6          | 31        | IN4   | B (right) - |
| -     | GND        | 39        | GND   | common ground |

## Motor Logic (digital, no PWM)

| IN1 | IN2 | Motor A     |
|-----|-----|-------------|
| H   | L   | Forward     |
| L   | H   | Backward    |
| L   | L   | Stop (coast)|

Same pattern for IN3/IN4 controlling Motor B.

## Notes

- ENA/ENB jumpers left in place (full speed). Remove jumpers and connect to Pi PWM pins for speed control later.
- Pi and L298N must share a common GND.
- L298N powered by 12V battery pack, not from Pi.
- Camera connects via CSI ribbon cable to the Pi camera port.
