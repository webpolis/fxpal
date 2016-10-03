#include <iostream>
#include <fstream>
#include <vector>
#include <opencv2/opencv.hpp>
#include "chartdir.h"
#include "csv.h"

using namespace std;
using namespace cv;

int lines(const char*);
bool drawCandles(const char*, const int, const int, const char*);
vector<Point> getCornerPoints(Mat);
vector<vector<Point> > getContourFromPoints(vector<Point>);

int main(int argc, char *argv[]) {
        // initialize chart extraction settings
        const char* csv = argv[1];
        int pTotal = lines(csv) - 1;
        int pLast = 110;

        // setup images names
        string cLast = string(csv) + to_string(pLast) + string(".png");
        string cTotal = string(csv) + to_string(pTotal) + string(".png");

        // compose charts
        drawCandles(csv, 100, pLast, cLast.c_str());
        drawCandles(csv, 0, 10, cTotal.c_str());

        // load up charts in grey scale
        Mat img1 = imread(cLast.c_str(), IMREAD_GRAYSCALE);
        Mat img2 = imread(cTotal.c_str(), IMREAD_GRAYSCALE);

        // get corner points
        vector<Point> cornerPoints1 = getCornerPoints(img1);
        vector<Point> cornerPoints2 = getCornerPoints(img2);

        // convert shape points into contour sequence
        vector<vector<Point> > shapeContour1 = getContourFromPoints(cornerPoints1);
        vector<vector<Point> > shapeContour2 = getContourFromPoints(cornerPoints2);

        double sh = matchShapes(shapeContour1.at(0), shapeContour2.at(0), CV_CONTOURS_MATCH_I1, 0);
        cout << "matching shapes by "<<sh << endl;

        // debug images
        drawContours(img1, shapeContour1, -1, Scalar(0,255,0), 1);
        imwrite(cLast, img1);
        drawContours(img2, shapeContour2, -1, Scalar(0,255,0), 1);
        imwrite(cTotal, img2);

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

bool drawCandles(const char* fname, const int start, const int end, const char* cname){
        double candleDimRatio = (end-start)*15;
        const int w = ceil(candleDimRatio);
        const int h = ceil(candleDimRatio/1.3333);

        // load data
        int rows = end-start;
        io::CSVReader<5> in(fname);

        double highData[rows];
        double lowData[rows];
        double openData[rows];
        double closeData[rows];

        in.read_header(io::ignore_extra_column, "date", "Open", "High", "Low", "Close");
        string date; double open; double high; double low; double close;

        int r = 0; int rr = 0;

        cout << "start-end "<<start<<","<<end<<" printing "<<rows<<endl;

        while(in.read_row(date, open, high, low, close)) {
                if(r >= start && r < end) {
                        highData[rr] = high;
                        lowData[rr] = low;
                        openData[rr] = open;
                        closeData[rr] = close;
                        //cout << highData[rr] << "," << lowData[rr] << "," << openData[rr] << "," << closeData[rr] << "," << endl;
                        rr++;
                }
                r++;
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

vector<Point> getCornerPoints(Mat img){
        int thresh = 200;
        int max_thresh = 255;
        Mat dst, dst_norm, dst_norm_scaled;
        dst = Mat::zeros(img.size(), CV_32FC1);
        vector<Point> points;

        // Detector parameters
        int blockSize = 2;
        int apertureSize = 3;
        double k = 0.04;

        // Detecting corners
        cornerHarris(img, dst, blockSize, apertureSize, k, BORDER_DEFAULT);

        // Normalizing
        normalize(dst, dst_norm, 0, 255, NORM_MINMAX, CV_32FC1, Mat());
        convertScaleAbs(dst_norm, dst_norm_scaled);

        // Drawing a circle around corners
        for(int j = 0; j < dst_norm.rows; j++)
        { for(int i = 0; i < dst_norm.cols; i++)
          {
                  if((int) dst_norm.at<float>(j,i) > thresh)
                  {
                          points.push_back(Point(i, j));
                  }
          }}

        return points;
}

vector<vector<Point> > getContourFromPoints(vector<Point> points){
        vector<Point> shapePoints;
        vector<int> hull; int i;
        convexHull(Mat(points), hull, true);

        int hullcount = (int)hull.size();

        for(i = 0; i < hullcount; i++)
        {
                Point pt = points[hull[i]];
                shapePoints.push_back(pt);
        }

        // convert shape points into contour sequence
        vector<vector<Point> > shapeContour;
        shapeContour.push_back(shapePoints);

        return shapeContour;
}
