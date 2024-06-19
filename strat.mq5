#include<Trade/Trade.mqh>

static input long InpMagicNumber = 837462;
static input double InpLotSize = 2;
input int InpPeriod = 21;
input double InpDeviation = 2.0;
input int InpStopLoss = 100;
input int InpTakeProfit = 200;

int handle;
double upperBuffer[];
double baseBuffer[];
double lowerBuffer[];
MqlTick currentTick;
CTrade trade;

datetime openTimeBuy = 0;
datetime openTimeSell = 0;
int OnInit()
{
    trade.SetExpertMagicNumber(InpMagicNumber);
    //Create handle
    handle = iBands(_Symbol, PERIOD_CURRENT, InpPeriod, 1, InpDeviation, PRICE_CLOSE);
    if(handle == INVALID_HANDLE){
      Alert("Failed to create handle");
      return INIT_FAILED;
    }
    //Set buffer as series
    ArraySetAsSeries(upperBuffer, true);
    ArraySetAsSeries(baseBuffer, true);
    ArraySetAsSeries(lowerBuffer, true);
    // Return value of initialization
    return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   if (handle == INVALID_HANDLE){
      IndicatorRelease(handle);
   }
    // Deinitialization code
    Print("Expert advisor deinitialized. Reason: ", reason);
}
void OnTick()
{
   if(!IsNewBar()) {return;}
   //Get current tick
   if(!SymbolInfoTick(_Symbol,currentTick)) {
      Print("Failed to get tick!");
      return;
   }
   //Get BB
   int values = CopyBuffer(handle, 0, 0, 1, baseBuffer) + CopyBuffer(handle, 1, 0, 1, upperBuffer) + CopyBuffer(handle, 2, 0, 1, lowerBuffer);
   if(values!=3) {
      Print("Failed to get indicator values");
      return;
   }
   Comment("UpperBand:", upperBuffer[0], "\nBase:", baseBuffer[0], "\nLowerBand:", lowerBuffer[0]);
 
   //Count open positions
   int countLong, countShort;
   if (!CountOpenPositions(countLong,countShort)){
      return;
   }
   double previousClose = iClose(_Symbol,PERIOD_CURRENT,1);
   double previousHigh = iHigh(_Symbol,PERIOD_CURRENT,1);
   int fractalCheck = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,5,1);
   bool isInBelowBBbands = (previousClose - lowerBuffer[0])/(upperBuffer[0] - lowerBuffer[0]) <= 0.17;
   
   //Buy and sell
   
   if(isInBelowBBbands == true && fractalCheck==3 && countLong == 0 && openTimeBuy != iTime(_Symbol,PERIOD_CURRENT,0)){
      openTimeBuy = iTime(_Symbol,PERIOD_CURRENT,0);
      double sl = currentTick.bid - InpStopLoss*_Point;
      double tp = currentTick.bid + InpTakeProfit*_Point;
      if(!NormalizePrice(sl,sl)){
         return;
      }
      if(!NormalizePrice(tp,tp)){
         return;
      }
      trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,InpLotSize,currentTick.ask,0,9999999,"LongPosition");
   }
   
   
   //check to close positions
   if(!CountOpenPositions(countLong,countShort)){
      return;
   }
   if(countLong>0 && previousHigh>=upperBuffer[0]){
      ClosePositions(1);
   }
}


bool IsNewBar(){
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol,PERIOD_CURRENT,0);
   if (previousTime != currentTime){
      previousTime = currentTime;
      return true;
   }
   return false;
}

bool CountOpenPositions(int &countBuy, int &countSell){
   countBuy= 0;
   countSell=0;
   int total = PositionsTotal();
   for(int i=total-1; i >=0; i--){
      ulong positionTicket = PositionGetTicket(i);
      if(positionTicket <= 0){
         Print("Failed to get ticket");
         return false;
      }
      if (!PositionSelectByTicket(positionTicket)){
         Print("Failed to select position");
         return false;
      }
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC, magic)){
         Print("Failed to get magic number");
         return false;
      }
      if (magic==InpMagicNumber){
         long type;
         if(!PositionGetInteger(POSITION_TYPE, type)){
            Print("Failed to get type");
            return false;
         }
         if(type==POSITION_TYPE_BUY){
            countBuy++;
         }
         if(type==POSITION_TYPE_SELL){
            countSell++;
         }
      }
   }
   return true;
}

bool NormalizePrice(double price, double &normalizePrice){
   double tickSize = 0;
   if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE, tickSize)){
      Print("Failed to get tick size");
      return false;
   }
   normalizePrice = NormalizeDouble(MathRound(price/tickSize)*tickSize, _Digits);
   return true;
}

bool ClosePositions(int all_buy_sell){
   int total = PositionsTotal();
   for(int i=total-1; i >=0; i--){
      ulong positionTicket = PositionGetTicket(i);
      if(positionTicket <= 0){
         Print("Failed to get ticket");
         return false;
      }
      if (!PositionSelectByTicket(positionTicket)){
         Print("Failed to select position");
         return false;
      }
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC, magic)){
         Print("Failed to get magic number");
         return false;
      }
      if (magic==InpMagicNumber){
         long type;
         if(!PositionGetInteger(POSITION_TYPE, type)){
            Print("Failed to get type");
            return false;
         }
         if(all_buy_sell==2 && type==POSITION_TYPE_BUY){
            continue;
         }
         if(all_buy_sell==1 && type==POSITION_TYPE_SELL){
            continue;
         }
         trade.PositionClose(positionTicket);
         if(trade.ResultRetcode()!=TRADE_RETCODE_DONE){
            Print("Failed to close position ticket:", (string)positionTicket, " result:",(string)trade.ResultRetcode()+":",trade.ResultRetcodeDescription());
            return false;
         }
         
      }
   }
   return true;
}
