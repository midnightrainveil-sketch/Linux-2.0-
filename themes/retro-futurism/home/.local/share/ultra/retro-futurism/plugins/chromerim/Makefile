# chromerim, against the installed Hyprland's headers (ultra-rim runs this)
ifeq ($(CXX),g++)
    EXTRA_FLAGS = --no-gnu-unique
else
    EXTRA_FLAGS =
endif

CXXFLAGS ?= -O2
CXXFLAGS += -shared -fPIC -std=c++2b -Wno-c++11-narrowing
INCLUDES = `pkg-config --cflags pixman-1 libdrm hyprland libinput libudev wayland-server xkbcommon cairo`
LIBS = `pkg-config --libs cairo`

SRC = main.cpp RimDeco.cpp
TARGET = chromerim.so

all: $(TARGET)

$(TARGET): $(SRC) RimDeco.hpp RimPaint.hpp
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $(EXTRA_FLAGS) $(INCLUDES) $(SRC) -o $@ $(LIBS)

clean:
	rm -f ./$(TARGET)

.PHONY: all clean
