#include <iostream>
#include <fstream>
#include <vector>
#include <opencv2/opencv.hpp>
#include <Rcpp.h>
#include "chartdir.h"
#include "csv.h"

using namespace std;
using namespace cv;
using namespace Rcpp;

struct ohlc {
        double open;
        double high;
        double low;
        double close;
        string date;
};

extern DataFrame processDf(DataFrame dfTpl, DataFrame dfSample);
void process(const int, const vector<ohlc>, const vector<ohlc>, const char*, const char*);
int err(int, const char*, const char*, const char*, int, void*);
int lines(const char*);
vector<ohlc> preloadData(const char*);
bool drawCandles(vector<ohlc>, const int, const int, const char*);
vector<Point> getCornerPoints(Mat);
vector<vector<Point> > getContourFromPoints(vector<Point>);
Mat extractMoments(Mat img);
void drawAxis(Mat&, Point, Point, Scalar, const float);
double getOrientation(const vector<Point> &, Mat&);

bool DEBUG_CMD = false;
const double MAX_ANGLE_P_ROTATION = 10;         // %
const double MAX_SHAPE_DIST = 0.1;

int err(int status, const char* func_name, const char* err_msg,
        const char* file_name, int line, void*){
        return 0;
}

int main(int argc, char *argv[]) {
        DEBUG_CMD = true;
        const char* csvTpl = argv[1];
        const char* csvSample = argv[2];
        const int period = atoi(argv[3]);

        vector<ohlc> dataTpl = preloadData(csvTpl);
        vector<ohlc> dataSample = preloadData(csvSample);
        process(period, dataTpl, dataSample, csvTpl, csvSample);

        return 0;
}

// [[Rcpp::export]]
extern DataFrame processDf(DataFrame dfTpl, DataFrame dfSample){
        DataFrame ret = DataFrame::create();

        return ret;
}

void process(const int period, const vector<ohlc> dataTpl, const vector<ohlc> dataSample, const char* csvTpl, const char* csvSample){
        try{
                cvRedirectError(err);

                // initialize chart extraction settings
                int rSampleStart = 0;
                int rSampleEnd = period;
                const int rTotalTpl = lines(csvTpl) - 1;
                const int rTotalSample = lines(csvSample) - 1;
                const int rTplStart = rTotalTpl - period;
                const int rTplEnd = rTplStart + period;

                // compose template chart and extract shape contour
                string cTpl = string(csvTpl) + string("-") + to_string(period) + string(".tpl") + string(".png");
                drawCandles(dataTpl, rTplStart, rTplEnd, cTpl.c_str());
                Mat imgTpl = imread(cTpl.c_str(), IMREAD_GRAYSCALE);

                Mat imgMm = extractMoments(imgTpl);
                vector<Point> cornerPointsTpl = getCornerPoints(imgMm);
                vector<vector<Point> > shapeContourTpl = getContourFromPoints(cornerPointsTpl);

                // debug template
                RotatedRect boxTpl = fitEllipse(shapeContourTpl.at(0));

                if(DEBUG_CMD) {
                        drawContours(imgTpl, shapeContourTpl, -1, Scalar(255, 255, 255), 1);
                        imwrite(cTpl, imgTpl);
                }

                const double pcaAngleTpl = getOrientation(shapeContourTpl.at(0), imgMm);

                //Ptr<ShapeContextDistanceExtractor> mysc = createShapeContextDistanceExtractor();

                // compose samples charts and extract shape contours
                const string cSample = string(csvSample) + to_string(period) + string(".sample") + string(".png");

                for(int n = 0; n < rTotalSample; n += period) {
                        rSampleStart = n;
                        rSampleEnd = rSampleStart + period;

                        if(rSampleEnd > rTotalSample) {
                                break;
                        }

                        drawCandles(dataSample, rSampleStart, rSampleEnd, cSample.c_str());
                        Mat imgSample = imread(cSample.c_str(), IMREAD_GRAYSCALE);
                        Mat imgSampleMm = extractMoments(imgSample);
                        vector<Point> cornerPointsSample = getCornerPoints(imgSampleMm);
                        vector<vector<Point> > shapeContourSample = getContourFromPoints(cornerPointsSample);
                        RotatedRect boxSample = fitEllipse(shapeContourSample.at(0));

                        // match shapes
                        const double sh = matchShapes(shapeContourTpl.at(0), shapeContourSample.at(0), CV_CONTOURS_MATCH_I1, 0);
                        //const float dist = mysc->computeDistance(cornerPointsTpl, cornerPointsSample);

                        // rotation diff
                        const double largestRotAngle = boxSample.angle > boxTpl.angle ? boxSample.angle : boxTpl.angle;
                        const double distRotAngle = (abs(boxSample.angle - boxTpl.angle) * largestRotAngle) / 100;

                        const double pcaAngleSample = getOrientation(shapeContourSample.at(0), imgSampleMm);
                        const double largestPcaAngle = pcaAngleSample > pcaAngleTpl ? pcaAngleSample : pcaAngleTpl;
                        const double distPcaAngle = abs(pcaAngleSample - pcaAngleTpl);

                        const bool isSame = (abs(sh) == 0 && abs(distRotAngle) == 0 && abs(distPcaAngle) == 0 && pcaAngleSample == pcaAngleTpl);

                        // interesting match
                        if(!isSame && sh <= MAX_SHAPE_DIST && (distRotAngle <= MAX_ANGLE_P_ROTATION) && distPcaAngle != 0) {
                                if(DEBUG_CMD) {
                                        // debug sample
                                        string cMatch = string("match") + string("-") + to_string(period) +  string("-") + to_string(n) + string(".png");
                                        drawContours(imgSample, shapeContourSample, -1, Scalar(255, 255, 255), 1);

                                        imwrite(cMatch, imgSample);

                                        cout << fixed << period << "," << sh << "," << distRotAngle << "," << distPcaAngle
                                             << "," << pcaAngleSample << "," << pcaAngleTpl << "," << cMatch << endl;
                                }
                        }

                }

                remove(cSample.c_str());

                if(!DEBUG_CMD)
                        remove(cTpl.c_str());
        }catch(Exception ex) {};
}

int lines(const char* filename){
        int number_of_lines = 0;
        string line;
        ifstream f(filename);

        while (getline(f, line))
                ++number_of_lines;

        return number_of_lines;
}

vector<ohlc> preloadData(const char* fname){
        vector<ohlc> ret;
        io::CSVReader<5> in(fname);

        in.read_header(io::ignore_extra_column, "date", "Open", "High", "Low", "Close");
        string date; double open; double high; double low; double close;

        while(in.read_row(date, open, high, low, close)) {
                ohlc data;
                data.open = open;
                data.high = high;
                data.low = low;
                data.close = close;
                data.date = date;
                ret.push_back(data);
        }

        return ret;
}

bool drawCandles(vector<ohlc> data, const int start, const int end, const char* cname){
        double candleDimRatio = (end-start)*15;
        const int w = ceil(candleDimRatio);
        const int h = ceil(candleDimRatio/1.3333);

        // load data
        int rows = end-start;

        ohlc ohlcs[rows];
        double highData[rows];
        double lowData[rows];
        double openData[rows];
        double closeData[rows];

        vector<ohlc>::iterator itStart = data.begin() + start;
        vector<ohlc>::iterator itEnd = data.begin() + end;
        copy(itStart, itEnd, ohlcs);

        for(int n = 0; n < rows; n++) {
                ohlc row = ohlcs[n];
                openData[n] = row.open;
                highData[n] = row.high;
                lowData[n] = row.low;
                closeData[n] = row.close;
        }

        // Create a XYChart object of size 600 x h pixels
        XYChart *c = new XYChart(w, h);

        // Set the plotarea at (50, 25) and of size 500 x 250 pixels. Enable both the horizontal and
        // vertical grids by setting their colors to grey (0xc0c0c0)
        c->setPlotArea(-1, -1, w, h, Transparent, -1, -1, Transparent, Transparent);
        c->setBorder(Transparent);
        c->setClipping(0);

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
        Rect roi(1,0,w-2,h-10);
        Mat cropped(img, roi);
        imwrite(cname, cropped);
}

vector<Point> getCornerPoints(Mat img){
        Mat dst, dst_norm;
        dst = Mat::zeros(img.size(), CV_32FC1);
        vector<Point> points;

        // Detector parameters
        int blockSize = 2;
        int apertureSize = 3;
        double k = 0.04;

        // Detecting corners
        cornerHarris(img, dst, blockSize, apertureSize, k, BORDER_CONSTANT);

        // Normalizing
        normalize(dst, dst_norm, 0, 255, NORM_MINMAX, CV_32FC1, Mat());

        for(int j = 0; j < dst_norm.rows; j++)
        { for(int i = 0; i < dst_norm.cols; i++)
          {
                  if((int) dst_norm.at<float>(j,i) > 200)
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

Mat extractMoments(Mat img){
        Mat imgCanny;
        vector<vector<Point> > contours;
        vector<Vec4i> hierarchy;

        threshold(img, img, 50, 255, CV_THRESH_BINARY_INV | CV_THRESH_OTSU);
        Canny(img, imgCanny, 100, 255, 3);
        findContours(imgCanny, contours, hierarchy, CV_RETR_LIST, CV_CHAIN_APPROX_NONE, Point(0, 0));

        /// Get the moments
        vector<Moments> mu(contours.size());
        for(int i = 0; i < contours.size(); i++)
        { mu[i] = moments(contours[i], true); }

        ///  Get the mass centers:
        vector<Point2f> mc(contours.size());
        for(int i = 0; i < contours.size(); i++)
        { mc[i] = Point2f(mu[i].m10/mu[i].m00, mu[i].m01/mu[i].m00); }

        /// Draw contours
        Scalar color = Scalar(255,255,255);

        /// Draw contours
        Mat drawing = Mat::zeros(imgCanny.size(), CV_8UC1);
        for(int i = 0; i< contours.size(); i++)
        {
                //drawContours(drawing, contours, i, color, 1, LINE_4, hierarchy, 2);
                circle(drawing, mc[i], 1, color, -1, 8, 0);
        }

        return drawing;
}

double getOrientation(const vector<Point> &pts, Mat &img)
{
        //Construct a buffer used by the pca analysis
        int sz = static_cast<int>(pts.size());
        Mat data_pts = Mat(sz, 2, CV_64FC1);
        for (int i = 0; i < data_pts.rows; ++i)
        {
                data_pts.at<double>(i, 0) = pts[i].x;
                data_pts.at<double>(i, 1) = pts[i].y;
        }
        //Perform PCA analysis
        PCA pca_analysis(data_pts, Mat(), CV_PCA_DATA_AS_ROW);
        //Store the center of the object
        Point cntr = Point(static_cast<int>(pca_analysis.mean.at<double>(0, 0)),
                           static_cast<int>(pca_analysis.mean.at<double>(0, 1)));
        //Store the eigenvalues and eigenvectors
        vector<Point2d> eigen_vecs(2);
        vector<double> eigen_val(2);
        for (int i = 0; i < 2; ++i)
        {
                eigen_vecs[i] = Point2d(pca_analysis.eigenvectors.at<double>(i, 0),
                                        pca_analysis.eigenvectors.at<double>(i, 1));
                eigen_val[i] = pca_analysis.eigenvalues.at<double>(0, i);
        }
        // Draw the principal components
        circle(img, cntr, 3, Scalar(255, 0, 255), 2);
        Point p1 = cntr + 0.02 * Point(static_cast<int>(eigen_vecs[0].x * eigen_val[0]), static_cast<int>(eigen_vecs[0].y * eigen_val[0]));
        Point p2 = cntr - 0.02 * Point(static_cast<int>(eigen_vecs[1].x * eigen_val[1]), static_cast<int>(eigen_vecs[1].y * eigen_val[1]));
        drawAxis(img, cntr, p1, Scalar(0, 255, 0), 1);
        drawAxis(img, cntr, p2, Scalar(255, 255, 0), 5);
        double angle = atan2(eigen_vecs[0].y, eigen_vecs[0].x); // orientation in radians
        return angle;
}

void drawAxis(Mat& img, Point p, Point q, Scalar colour, const float scale = 0.2)
{
        double angle;
        double hypotenuse;
        angle = atan2( (double) p.y - q.y, (double) p.x - q.x ); // angle in radians
        hypotenuse = sqrt( (double) (p.y - q.y) * (p.y - q.y) + (p.x - q.x) * (p.x - q.x));
//    double degrees = angle * 180 / CV_PI; // convert radians to degrees (0-180 range)
//    cout << "Degrees: " << abs(degrees - 180) << endl; // angle in 0-360 degrees range
        // Here we lengthen the arrow by a factor of scale
        q.x = (int) (p.x - scale * hypotenuse * cos(angle));
        q.y = (int) (p.y - scale * hypotenuse * sin(angle));
        line(img, p, q, colour, 1, CV_AA);
        // create the arrow hooks
        p.x = (int) (q.x + 9 * cos(angle + CV_PI / 4));
        p.y = (int) (q.y + 9 * sin(angle + CV_PI / 4));
        line(img, p, q, colour, 1, CV_AA);
        p.x = (int) (q.x + 9 * cos(angle - CV_PI / 4));
        p.y = (int) (q.y + 9 * sin(angle - CV_PI / 4));
        line(img, p, q, colour, 1, CV_AA);
}

RCPP_MODULE(cvm){
        Rcpp::function("process", &processDf);
}
