#
# Compiler to use
#
CC = g++

#
# Where the libraries and include files are located.
#
CFLAGS = -std=c++0x -I/home/nico/dev/ChartDirector/include -L/usr/local/lib -L/home/nico/dev/ChartDirector/lib -Wl,-R/home/nico/dev/ChartDirector/lib
LIBS = -lchartdir -lopencv_shape -lopencv_stitching -lopencv_objdetect -lopencv_superres -lopencv_features2d -lopencv_highgui -lopencv_imgcodecs -lopencv_photo -lopencv_ml -lopencv_imgproc -lopencv_flann -lopencv_core -lpthread
TARGET = main


all: $(TARGET)

$(TARGET): $(TARGET).cpp
	$(CC) $(CFLAGS) $(TARGET).cpp $(LIBS) -o $@

test: all
	./$(TARGET)

clean:
	rm -f $(TARGET) *.o *.png
