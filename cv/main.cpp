#include <iostream>
#include <fstream>
#include <vector>
#include <opencv2/opencv.hpp>
#include "chartdir.h"
#include "csv.h"

using namespace std;
using namespace cv;

int lines(const char*);
bool drawChart(const char*, const int, const char*);

int main(int argc, char const *argv[]) {
        const char* csv = argv[1];
        const int pLast = 10;
        const int pTotal = lines(csv) - 1;
        string cLast = string(csv) + to_string(pLast) + string(".png");
        string cTotal = string(csv) + to_string(pTotal) + string(".png");

        drawChart(csv, pLast, cLast.c_str());
        drawChart(csv, pTotal/3, cTotal.c_str());

        Mat img1 = imread(cLast.c_str(), IMREAD_GRAYSCALE);
        Mat img2 = imread(cTotal.c_str(), IMREAD_GRAYSCALE);


        int thresh = 200;
        int max_thresh = 255;
        Mat dst, dst_norm, dst_norm_scaled;
        dst = Mat::zeros( img1.size(), CV_32FC1 );
        vector<Point> points;

/// Detector parameters
        int blockSize = 2;
        int apertureSize = 3;
        double k = 0.04;

/// Detecting corners
        cornerHarris( img1, dst, blockSize, apertureSize, k, BORDER_DEFAULT );

/// Normalizing
        normalize( dst, dst_norm, 0, 255, NORM_MINMAX, CV_32FC1, Mat() );
        convertScaleAbs( dst_norm, dst_norm_scaled );

/// Drawing a circle around corners
        for( int j = 0; j < dst_norm.rows; j++ )
        { for( int i = 0; i < dst_norm.cols; i++ )
          {
                  if( (int) dst_norm.at<float>(j,i) > thresh )
                  {
                          points.push_back(Point( i, j ));
                  }
          }}

        vector<int> hull; int i;
        convexHull(Mat(points), hull, true);

        for( i = 0; i < points.size(); i++ )
                circle(img1, points[i], 3, Scalar(0, 0, 255), FILLED, LINE_AA);

        int hullcount = (int)hull.size();
        Point pt0 = points[hull[hullcount-1]];

        for( i = 0; i < hullcount; i++ )
        {
                Point pt = points[hull[i]];
                line(img1, pt0, pt, Scalar(0, 255, 0), 1,LINE_AA);
                pt0 = pt;
        }

        imwrite("out.png", img1);

        return 0;
}

int lines(const char* filename){
        int number_of_lines = 0;
        string line;
        ifstream f(filename);

        while (getline(f, line))
                ++number_of_lines;

        return number_of_lines;
}

bool drawChart(const char* fname, const int tail, const char* cname){
        const int w = tail > 10 ? tail * 9 : 320;
        const int h = tail > 10 ? ceil(w/2) : 240;

        // load data
        const int rows = tail; //lines(fname) - 1;
        io::CSVReader<5> in(fname);

        double highData[rows];
        double lowData[rows];
        double openData[rows];
        double closeData[rows];

        in.read_header(io::ignore_extra_column, "date", "Open", "High", "Low", "Close");
        string date; double open; double high; double low; double close;

        int r = 0;
        while(in.read_row(date, open, high, low, close)) {
                highData[r] = high;
                lowData[r] = low;
                openData[r] = open;
                closeData[r] = close;
                //cout << highData[r] << "," << lowData[r] << "," << openData[r] << "," << closeData[r] << "," << endl;
                r++;

                if(r>=tail)
                        break;
        }

        // Create a XYChart object of size 600 x h pixels
        XYChart *c = new XYChart(w, h);

        // Set the plotarea at (50, 25) and of size 500 x 250 pixels. Enable both the horizontal and
        // vertical grids by setting their colors to grey (0xc0c0c0)
        c->setPlotArea(0, 0, w, h, Transparent, -1, -1, Transparent, Transparent);

        // Add a CandleStick layer to the chart using green (00ff00) for up candles and red (ff0000) for
        // down candles
        CandleStickLayer *layer = c->addCandleStickLayer(DoubleArray(highData, (int)(sizeof(highData) /
                                                                                     sizeof(highData[0]))), DoubleArray(lowData, (int)(sizeof(lowData) / sizeof(lowData[0]))),
                                                         DoubleArray(openData, (int)(sizeof(openData) / sizeof(openData[0]))), DoubleArray(closeData,
                                                                                                                                           (int)(sizeof(closeData) / sizeof(closeData[0]))), 0x00ff00, 0xff0000);

        // Set the line width to 2 pixels
        layer->setLineWidth(2);
        layer->setBorderColor(Transparent);

        // Output the chart
        c->makeChart(cname);

        delete c;

        // sanitize chart
        Mat img = imread(cname, IMREAD_GRAYSCALE);
        Rect roi(0,0,w,h-10);
        Mat cropped(img, roi);
        imwrite(cname, cropped);
}
