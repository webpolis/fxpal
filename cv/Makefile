#
# Compiler to use
#
CC = g++

#
# Where the libraries and include files are located.
#
CFLAGS = -std=c++0x -I/usr/share/R/include -I/usr/lib/R/site-library/Rcpp/include -I/home/nico/dev/ChartDirector/include -L/usr/local/lib -L/home/nico/dev/ChartDirector/lib -Wl,-R/home/nico/dev/ChartDirector/lib
LIBS = -lR -lchartdir -lopencv_shape -lopencv_stitching -lopencv_objdetect -lopencv_superres -lopencv_features2d -lopencv_highgui -lopencv_imgcodecs -lopencv_photo -lopencv_ml -lopencv_imgproc -lopencv_flann -lopencv_core -lpthread
TARGET = CVMatcher


lib: $(TARGET)

$(TARGET): $(TARGET).cpp
	$(CC) $(CFLAGS) $(TARGET).cpp $(LIBS) -o $@
	$(CC) -fPIC $(CFLAGS) -c $(TARGET).cpp -o $@.o
	$(CC)  $(CFLAGS) -shared -Wl,-soname,$@.so.1 -o $@.so.1.0 $@.o $(LIBS)

test: all
	./$(TARGET)

clean:
	rm -f $(TARGET) $(TARGET).so* *.o *.png
