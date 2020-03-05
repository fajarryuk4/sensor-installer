# FROM mataelang/snorqttalpine-sensor:latest
FROM mataelang/snorqttalpine-sensor:latest

ARG OINKCODE
COPY conf/pulledpork-registered.conf /etc/snort/pulledpork.conf

# Setting up rules
RUN sed -i 's@.oinkcode.@'"${OINKCODE}"'@' /etc/snort/pulledpork.conf