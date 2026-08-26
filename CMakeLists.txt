cmake_minimum_required(VERSION 3.15)
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_C_COMPILER arm-none-eabi-gcc)
set(CMAKE_C_COMPILER_WORKS 1)
set(CMAKE_C_FLAGS "-Os -g")
set(CMAKE_C_FLAGS_DEBUG "-Og")
project(ESCape32 C)
if(UNIX AND NOT CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT) # Use 'CMAKE_INSTALL_PREFIX' as alternative system root
	set(CMAKE_PREFIX_PATH ${CMAKE_INSTALL_PREFIX})
	include(GNUInstallDirs)
	include_directories(${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_INCLUDEDIR})
	link_directories(${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR})
endif()
if(LIBOPENCM3_DIR)
	include_directories(${LIBOPENCM3_DIR}/include)
	link_directories(${LIBOPENCM3_DIR}/lib)
endif()
add_compile_options(-ffreestanding -ffunction-sections -fdata-sections -fsingle-precision-constant
	-Wall -Wextra -Wpedantic -Wundef -Wshadow -Wredundant-decls -Wstrict-prototypes -Wmissing-prototypes
	-Wno-variadic-macros -Wno-unused-result -Wno-unused-parameter)
add_link_options(-nostartfiles -Wl,--gc-sections)

# Appended to every build artifact's filename (elf/bin/hex), not to the CMake
# target name itself -- so `make AART1` / `flash-AART1` etc. keep working
# unchanged. This fork publishes into the same release repo as
# aartech-dev/ESCape32, which builds the AART* targets under identical names
# with no such suffix -- BUILD_TAG keeps this fork's artifacts distinguishable
# from theirs. Override with `cmake -B build -D BUILD_TAG=...`.
set(BUILD_TAG "-ab" CACHE STRING "Suffix appended to build artifact filenames")

function(add_target name mcu)
	include(mcu/${mcu}/config.cmake)
	file(READ src/main.c main_c)
	string(REGEX MATCH "REVISION [0-9]+" rev1 ${main_c})
	string(REGEX MATCH "REVPATCH [0-9]+" rev2 ${main_c})
	string(REGEX REPLACE "[^0-9]+" "-rev" rev1 ${rev1})
	if (rev2)
		string(REGEX REPLACE "[^0-9]+" "." rev2 ${rev2})
	endif()
	set(elf ${name}${rev1}${rev2}${BUILD_TAG}.elf)
	set(bin ${name}${rev1}${rev2}${BUILD_TAG}.bin)
	set(hex ${name}${rev1}${rev2}${BUILD_TAG}.hex)
	file(GLOB srcs src/*.c mcu/${mcu}/*.c)
	add_executable(${elf} ${srcs})
	if("SMALL_DEVICE" IN_LIST ARGN)
		target_compile_options(${elf} PRIVATE -Wno-unused-variable -Wno-unused-function)
		set(size 32K)
	else()
		set(size 64K)
	endif()
	target_include_directories(${elf} PRIVATE src mcu/${mcu})
	target_compile_options(${elf} PRIVATE ${opts})
	target_compile_definitions(${elf} PRIVATE ${mcu} ${name} ${defs} TARGET_NAME="${name}" ${ARGN})
	target_link_options(${elf} PRIVATE -Wl,--defsym,FLASH_SIZE=${size} -T${CMAKE_CURRENT_SOURCE_DIR}/mcu/${mcu}/config.ld -T${CMAKE_CURRENT_SOURCE_DIR}/mcu/common.ld ${opts})
	target_link_libraries(${elf} c_nano gcc nosys ${libs})
	add_custom_command(
		OUTPUT ${bin} ${hex}
		COMMAND arm-none-eabi-objcopy -O binary ${elf} ${bin}
		COMMAND arm-none-eabi-objcopy -O ihex ${elf} ${hex}
		DEPENDS ${elf}
	)
	add_custom_target(${name} ALL DEPENDS ${hex})
	add_custom_target(flash-${name} COMMAND st-flash --reset --connect-under-reset --format ihex write ${hex} DEPENDS ${hex})
endfunction()

add_subdirectory(boot)

add_target(AART1 AT32F421 DEAD_TIME=0 FREQ_MIN=48 FREQ_MAX=96 COMP_MAP=123 ARM=0 VOLUME=0 INPUT_MODE=1 ANALOG_CHAN=6 ANALOG_MIN=0 ANALOG_MAX=1440 DUTY_MIN=100 DUTY_SPUP=25 FULL_DUTY IO_RXTX)
add_target(AARTG AT32F421 DEAD_TIME=24 COMP_MAP=123 ARM=0 VOLUME=0 INPUT_MODE=1 ANALOG_CHAN=6 ANALOG_MIN=0 ANALOG_MAX=1440 DUTY_MIN=100 DUTY_SPUP=20 DUTY_RAMP=0 DUTY_RATE=20 DUTY_DRAG=0 DUTY_LOCK=0 THROT_SET=100 FULL_DUTY IO_RXTX DAMP=1 TIMING=18 FREQ_MIN=48 FREQ_MAX=96)
add_target(AARTIT AT32F421 TIMING=12 FREQ_MIN=48 FREQ_MAX=48 DUTY_RATE=20 DUTY_SPUP=20 DEAD_TIME=24 COMP_MAP=123 ARM=0 VOLUME=0 INPUT_MODE=1 ANALOG_CHAN=6 ANALOG_MIN=0 ANALOG_MAX=1440 DUTY_MIN=100 FULL_DUTY IO_RXTX)
add_target(AART2 AT32F421 TIMING=15 FREQ_MIN=48 FREQ_MAX=96 DUTY_RATE=20 DUTY_SPUP=20 DEAD_TIME=24 COMP_MAP=123 ARM=0 VOLUME=0 INPUT_MODE=1 ANALOG_CHAN=6 ANALOG_MIN=0 ANALOG_MAX=1440 DUTY_MIN=100 FULL_DUTY IO_RXTX)
add_target(AART2RF AT32F421 TIMING=20 FREQ_MIN=48 FREQ_MAX=96 DUTY_RATE=20 DUTY_SPUP=20 DEAD_TIME=24 COMP_MAP=123 ARM=0 VOLUME=0 INPUT_MODE=1 ANALOG_CHAN=6 ANALOG_MIN=0 ANALOG_MAX=1440 DUTY_MIN=100 FULL_DUTY IO_RXTX)
add_target(AART3NSR AT32F421 TIMING=15 FREQ_MIN=48 FREQ_MAX=96 DUTY_RATE=20 DUTY_SPUP=20 DEAD_TIME=13 COMP_MAP=123 ARM=0 VOLUME=0 INPUT_MODE=1 ANALOG_CHAN=6 ANALOG_MIN=0 ANALOG_MAX=1440 DUTY_MIN=100 FULL_DUTY IO_RXTX)
add_target(AART4WNG AT32F421 TIMING=20 FREQ_MIN=64 FREQ_MAX=128 DUTY_RATE=20 DUTY_SPUP=64 DEAD_TIME=13 COMP_MAP=123 ARM=0 VOLUME=0 INPUT_MODE=1 ANALOG_CHAN=6 ANALOG_MIN=0 ANALOG_MAX=1440 DUTY_MIN=100 FULL_DUTY IO_RXTX)
