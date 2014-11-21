//+------------------------------------------------------------------+
//|                                                          CCI.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Commodity Channel Index"
#property strict

#include <MovingAverages.mqh>

#property indicator_separate_window
#property indicator_buffers    1
#property indicator_color1     LightSeaGreen
#property indicator_level1    -100.0
#property indicator_level2     100.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT
//--- input parameter
input int InpCCIPeriod=14; // CCI Period
//--- buffers
double ExtCCIBuffer[];
double ExtPriceBuffer[];
double ExtMovBuffer[];
double last_cci=0,max_cci=10000,min_cci=10000,max_rbi=0,min_rbi=0;
int notice_level=0;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   string short_name;
//--- 2 additional buffers are used for counting.
   IndicatorBuffers(3);
   SetIndexBuffer(1,ExtPriceBuffer);
   SetIndexBuffer(2,ExtMovBuffer);
//--- indicator line
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0,ExtCCIBuffer);
//--- check for input parameter
   if(InpCCIPeriod<=1)
     {
      Print("Wrong input parameter CCI Period=",InpCCIPeriod);
      return(INIT_FAILED);
     }
//---
   SetIndexDrawBegin(0,InpCCIPeriod);
//--- name for DataWindow and indicator subwindow label
   short_name="CCI("+IntegerToString(InpCCIPeriod)+")";
   IndicatorShortName(short_name);
   SetIndexLabel(0,short_name);
//--- initialization done
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Commodity Channel Index                                          |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   int    i,k,pos;
   double dSum,dMul;
//---
   if(rates_total<=InpCCIPeriod || InpCCIPeriod<=1)
      return(0);
//--- counting from 0 to rates_total
   ArraySetAsSeries(ExtCCIBuffer,false);
   ArraySetAsSeries(ExtPriceBuffer,false);
   ArraySetAsSeries(ExtMovBuffer,false);
   ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false);
   ArraySetAsSeries(close,false);
//--- initial zero
   if(prev_calculated<1)
     {
      for(i=0; i<InpCCIPeriod; i++)
        {
         ExtCCIBuffer[i]=0.0;
         ExtPriceBuffer[i]=(high[i]+low[i]+close[i])/3;
         ExtMovBuffer[i]=0.0;
        }
     }
//--- calculate position
   pos=prev_calculated-1;
   if(pos<InpCCIPeriod)
      pos=InpCCIPeriod;
//--- typical price and its moving average
   for(i=pos; i<rates_total; i++)
     {
      ExtPriceBuffer[i]=(high[i]+low[i]+close[i])/3;
      ExtMovBuffer[i]=SimpleMA(i,InpCCIPeriod,ExtPriceBuffer);
     }
//--- standard deviations and cci counting
   dMul=0.015/InpCCIPeriod;
   pos=InpCCIPeriod-1;
   if(pos<prev_calculated-1)
      pos=prev_calculated-2;
   i=pos;
   while(i<rates_total)
     {
      dSum=0.0;
      k=i+1-InpCCIPeriod;
      while(k<=i)
        {
         dSum+=MathAbs(ExtPriceBuffer[k]-ExtMovBuffer[i]);
         k++;
        }
      dSum*=dMul;
      if(dSum==0.0)
         ExtCCIBuffer[i]=0.0;
      else
         ExtCCIBuffer[i]=(ExtPriceBuffer[i]-ExtMovBuffer[i])/dSum;
      i++;
     }
//--- CCI買進賣出邏輯判斷
   double CCI = iCCI(Symbol(),0,InpCCIPeriod,PRICE_TYPICAL,0);   
   double MA = iMA(Symbol(),0,14,0,MODE_EMA,PRICE_CLOSE,0);
   double Price = MarketInfo(Symbol(),MODE_ASK);
   double RBI = MA - Price;
   string notice_message = "", rollback_message = "";
   string notice_log = "";
   int now_minute = TimeMinute(TimeCurrent());
   int now_hour = TimeHour(TimeCurrent());
   if(now_minute % 5 == 0) {
      //記錄單日CCI最高值與最低值
      if(10000 == max_cci && 10000 == min_cci) {
         notice_log += "\n\n[系統日誌]\n";
         notice_log += "因系統維護因素，故已重置" + Symbol() + " CCI最高值與最低值";
         max_cci = CCI;
         min_cci = CCI;
      }
      else if(0 == now_hour) {
         notice_log += "\n\n[系統日誌]\n";
         notice_log += "前一日之" + Symbol() + " CCI最高值為" + DoubleToString(max_cci) + "，最低值為" + DoubleToString(min_cci);
         max_cci = CCI;
         min_cci = CCI;
         max_rbi = 0;
         min_rbi = 0;
      }
      else if(CCI > max_cci) {
         max_cci = CCI;
      }
      else if(CCI < min_cci) {
         min_cci = CCI;
      }
      //記錄單日RBI最高值與最低值
      if(0 > RBI && min_rbi > RBI) {
         min_rbi = RBI;
      }
      else if(0 < RBI && max_rbi < RBI) {
         max_rbi = RBI;
      }
      //檢查景氣是否回升
      if(0 == last_cci) {
         last_cci = CCI;
      }
      else if(CCI < last_cci){
         rollback_message = "[持續下跌]";
         last_cci = CCI;
      }
      else if(CCI > last_cci) {
         rollback_message = "[持續上昇]";
         last_cci = CCI;
      }
      //判斷CCI範圍
      if(-300 >= CCI && 1 != notice_level) {
         notice_level = 1;
         notice_message = "品項：" + Symbol() + "\n";
         notice_message += "建議：嚴重超賣，宜繼續觀望\n";
      }
      else if(-299 <= CCI && -250 >= CCI && 2 != notice_level) {
         notice_level = 2;
         notice_message = "品項：" + Symbol() + "\n";
         notice_message += "建議：已達超賣區4，可買進\n";
      }
      else if(-249 <= CCI && -200 >= CCI && 3 != notice_level) {
         notice_level = 3;
         notice_message = "品項：" + Symbol() + "\n";
         notice_message += "建議：已達超賣區3，可買進\n";
      }
      else if(-199 <= CCI && -150 >= CCI && 4 != notice_level) {
         notice_level = 4;
         notice_message = "品項：" + Symbol() + "\n";
         notice_message += "建議：已達超賣區2，可買進\n";
      }
      else if(-149 <= CCI && -100 >= CCI && 5 != notice_level) {
         notice_level = 5;
         notice_message = "品項：" + Symbol() + "\n";
         notice_message += "建議：已達超賣區1，可買進\n";
      }
      else if(-99 <= CCI && 0 >= CCI && 6 != notice_level) {
         notice_level = 6;
         notice_message = "品項：" + Symbol() + "\n";
         notice_message += "建議：預備到達超賣區，可準備買進\n";
      }
      else if(150 >= CCI && 101 <= CCI && 7 != notice_level) {
         notice_level = 7;
         notice_message = "品項：" + Symbol() + "\n";
         notice_message += "建議：已達超買區1，可清倉\n";
      }
      else if(200 >= CCI && 151 <= CCI && 8 != notice_level) {
         notice_level = 8;
         notice_message = "品項：" + Symbol() + "\n";
         notice_message += "建議：已達超買區2，可清倉\n";
      }
      else if(250 >= CCI && 201 <= CCI && 9 != notice_level) {
         notice_level = 9;
         notice_message = "品項：" + Symbol() + "\n";
         notice_message += "建議：已達超買區3，可清倉\n";
      }
      else if(300 >= CCI && 251 <= CCI && 10 != notice_level) {
         notice_level = 10;
         notice_message = "品項：" + Symbol() + "\n";
         notice_message += "建議：已達超買區4，可清倉\n";
      }
      else if(300 < CCI && 11 != notice_level) {
         notice_level = 11;
         notice_message = "品項：" + Symbol() + "\n";
         notice_message += "建議：嚴重買超，宜清倉\n";
      }
      if("" != notice_message) {
         notice_message += "CCI：" + DoubleToString(CCI) + rollback_message + "\n";
         notice_message += "最高值(單日)︰" + DoubleToString(max_cci) + "\n";
         notice_message += "最低值(單日)︰" + DoubleToString(min_cci) + "\n";
         notice_message += "MA︰" + DoubleToString(MA) + "\n";
         notice_message += "匯價︰" + DoubleToString(Price) + "\n";
         notice_message += "RBI上昇(單日)︰" + DoubleToString(max_rbi) + "\n";
         notice_message += "RBI下降(單日)︰" + DoubleToString(min_rbi);
         notice_message += notice_log;
         SendNotification(notice_message);
         Alert(notice_message);
      }
   }
   return(rates_total);
  }
//+------------------------------------------------------------------+
