FROM alpine

COPY /build /build/ 
COPY /source /source/

COPY bash_history /bash_history.txt

COPY run_moon.sh /run_moon.sh

# docker buildx build --platform arm64,amd64 -t newton2022/moonray:code --push --load .
# [+] Building 6.7s (1/1) FINISHED                                                                                                          docker-container:builder
#  => [internal] booting buildkit                                                                                                                               6.5s
#  => => pulling image moby/buildkit:buildx-stable-1                                                                                                            5.2s
#  => => creating container buildx_buildkit_builder0                                                                                                            1.2s
# ERROR: docker exporter does not currently support exporting manifest lists