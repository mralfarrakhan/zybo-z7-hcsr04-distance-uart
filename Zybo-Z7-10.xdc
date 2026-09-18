## =========================================================
## Zybo Z7-10 - HC-SR04 Ultrasonic Distance over UART
## 125 MHz system clock
## =========================================================

set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports clk]

create_clock -period 8.000 -name sys_clk_pin [get_ports clk]

## =========================================================
## HC-SR04
## Pmod JD (physical pin numbering, standard 12-pin Pmod)
##   pin1 = jd[0] = T14   <- ECHO (through 1.8k/3.3k divider, 5V -> 3.3V)
##   pin5 = GND
##   pin7 = jd[4] = U14   <- TRIG (direct, FPGA output)
## =========================================================

## HC-SR04 TRIG -> JD pin 7
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports hc_trig]

## HC-SR04 ECHO -> JD pin 1
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} [get_ports hc_echo]

## =========================================================
## UART TX
## Pmod JE (physical pin numbering, standard 12-pin Pmod)
##   pin1 = je[0] = V12   <- dongle TXD (FPGA RX) - NOT used by this design, left unconstrained
##   pin5 = GND
##   pin7 = je[4] = V13   <- dongle RXD (FPGA TX)
## FPGA TX -> CP210x RXD
## =========================================================

set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports uart_tx]
