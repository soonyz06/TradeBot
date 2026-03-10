#include<Trade\Trade.mqh>
CTrade trade;

input group "===   Inputs   ===";
input ulong Magic = 120;
input ENUM_TIMEFRAMES Timeframe = PERIOD_D1;
input double FixedRisk = 0.01;
input double VariableRisk = 0;
input double MinLot = 1;
double Lot;
int Mode = 0;
double initial_balance;

input group "===   Settings   ===";
input double TpATR1 = -1; //TP
double TpATR2 = TpATR1; 
input double SlATR = 1.5; //SL
input int TimeExit1 = -1; //Time Exit
int TimeExit2= TimeExit1;
double TriggerATR = 0;
double entry_spread=1;
double exit_spread=0.01;

input group "===   Time   ===";
input int A = 16; //Start Time
int B = 22; //Stop Time
int Z = A; //Exit Time
int E = 18; //Expiration Time
//16:30-23:00

//Variables
string today;
string yesterday;
datetime Start;
datetime Stop;
datetime Exit;
datetime Expiration;
string Trade_Start = string(A)+":45:00"; //Start Time
string Trade_Stop = string(B)+":45:00"; //Stop Time
string Trade_Exit = string(Z)+":35:00"; //Exit Time
string Trade_Expiration = string(E)+":00:00"; //Expiration Time
int bar1;
int bar2;
int newbar;
string text;
int buyPosition;
int sellPosition;
int buyDuration =-1;
int sellDuration =-1;

MqlRates Price[];
double High[];
double Low[];
double Highest = 0;
double Lowest = DBL_MAX;
double oldHigh;
double oldLow;
double ATR[];
int ATRHandler;
double predictions[] = {249.33423, 250.60535, 252.33778, 253.33301, 253.96655, 254.36281, 254.88115, 254.9691, 255.3782, 255.8072, 255.78102, 255.81929, 255.71175, 254.869, 252.46086, 250.12045, 248.66396, 246.2776, 245.37154, 246.13455, 246.25897, 244.78438, 243.2971, 243.40843, 242.60948, 243.67038, 244.35847, 246.15149, 247.27122, 247.79877, 248.81343, 249.37189, 248.04584, 246.66696, 246.99155, 247.83763, 248.06784, 247.40694, 247.86331, 247.96999, 247.15865, 247.45732, 249.49371, 253.01434, 255.57455, 257.91696, 260.387, 262.77332, 264.42664, 266.10703, 266.4595, 267.46536, 268.46912, 268.64362, 268.50232, 268.88364, 268.30057, 268.78036, 269.31885, 269.8635, 268.37015, 266.4872, 264.86917, 263.59274, 261.67917, 259.91168, 259.50235, 260.1429, 259.5088, 258.7462, 256.28345, 255.292, 256.02167, 256.10056, 255.66722, 255.31487, 255.92635, 256.1651, 257.7983, 259.41748, 260.59924, 260.836, 260.92624, 260.28897, 259.6458, 258.69907, 259.2617, 260.64276, 261.52542, 262.43747, 264.03732, 265.43503, 266.94263, 267.62415, 267.72345, 268.54263, 268.7715, 269.67856, 271.11804, 272.17664, 273.27356, 273.61267, 274.6763, 276.156, 277.14734, 277.9826, 280.05945, 281.67212, 283.37708, 283.94147, 284.2987, 284.2775, 285.07654, 286.0885, 286.4849, 286.62958, 285.7201, 285.4804, 285.84714, 287.39398, 289.57834, 291.13992, 291.59747, 291.67337, 291.6614, 291.17487, 290.70456, 290.90582, 290.96793, 291.78397, 292.45538, 292.67612, 292.30743, 292.06906, 292.58557, 293.7978, 295.22272, 295.9331, 295.78598, 297.03592, 299.90768, 302.2547, 303.44452, 303.98914, 303.49573, 303.09085, 303.66928, 303.7412, 303.75507, 303.57858, 303.4192, 303.05865, 302.78186, 301.85455, 300.7351, 300.20047, 300.56863, 302.21588, 303.7081, 303.52515, 301.8374, 300.48535, 300.37955, 300.67438, 300.94608, 299.90793, 296.37653, 293.59583, 291.02512, 291.01147, 289.86676, 290.5006, 292.30127, 294.28534, 295.82953, 296.76028, 296.98602, 297.85028, 300.0642, 302.1569, 304.4404, 306.31247, 307.37967, 308.81314, 309.40652, 309.4516, 309.83847, 313.25156, 316.2812, 320.2351, 322.60953, 325.0209, 326.83966, 328.5703, 329.62326, 330.46304, 330.72964, 329.614, 329.00702, 329.54486, 329.88327, 330.951, 331.70474, 332.7369, 333.91525, 334.01355, 333.47946, 333.03604, 330.76773, 330.56552, 329.14594, 327.95288, 326.97125, 324.7787, 323.8618, 325.37112, 326.76733, 327.4451, 330.09607, 331.42712, 329.73117, 329.64178, 327.30356, 325.1415, 322.59906, 322.47522, 324.03687, 325.79648, 329.0042, 331.1977, 332.87582, 333.37152};
datetime lastPlottedDay = 0;
int arrayIndex = 0; 
//---------------------------------------------------------------------------------------------------------



void OnInit(){
   trade.SetExpertMagicNumber(Magic);
   text = string(Magic);
   bar1=0;
   bar2=0;
   yesterday="";
   initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   ArraySetAsSeries(Price, true);
   ArraySetAsSeries(High, true);
   ArraySetAsSeries(Low, true);
   ArraySetAsSeries(ATR, true);
   ObjectCreate(0, "High", OBJ_HLINE, 0, 0, 0);
   ObjectCreate(0, "Low", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "High", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Low", OBJPROP_COLOR, clrWhite);
   ATRHandler = iATR(_Symbol, PERIOD_D1, 50);
   Comment("ID: ", Magic);
   CheckPositions();
}

void OnTick(){
   today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today!=yesterday)
   {      
      Start = StringToTime(today+" "+Trade_Start);
      Stop = StringToTime(today+" "+Trade_Stop);
      Exit = StringToTime(today+" "+Trade_Exit);
      Expiration = StringToTime(today+" "+Trade_Expiration);
      CopyBuffer(ATRHandler, 0, 0, 3, ATR);
      yesterday=today;
   }


   newbar= iBars(_Symbol, Timeframe);
   if(bar1!=newbar){
      if(TimeCurrent()>=Start){
         CopyRates(_Symbol, Timeframe, 0, 3, Price);
         CheckPositions();
         if (buyPosition==0 && Price[0].open<predictions[arrayIndex] && predictions[arrayIndex]-Price[0].open>ATR[1]*entry_spread){ 
            ExecuteBuy();
         }
         else if(buyPosition>0 && Price[0].open>predictions[arrayIndex] && Price[0].open-predictions[arrayIndex]>ATR[1]*exit_spread){
            ClosePosition(POSITION_TYPE_BUY);
         }
         PlotNextDataPoint(predictions);
         bar1=newbar;
      }
   }
   
   if(bar2!=newbar){
      if(TimeCurrent()>=Exit){
         
         bar2=newbar;
      }
   }
}



//---------------------------------------------------------------------------------------------------------



void PositionSize(){
   if(FixedRisk>0){
      Lot = int((initial_balance*FixedRisk)/(ATR[1]*SlATR));
   }
   else if(VariableRisk<=0){
      Lot = MinLot;
   }
   else{
      int _rounded_balance = int(AccountInfoDouble(ACCOUNT_BALANCE)/10)*10;
      Lot = int((_rounded_balance*VariableRisk)/(ATR[1]*SlATR));
      
   }
   
   if(Lot<MinLot) Lot=MinLot;
   if(Lot>1000) Lot=1000;
}

void ExecuteBuy(double slpoints=NULL, double tppoints=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(tppoints==NULL && Mode==0 && TpATR1>0) tppoints = Ask+TpATR1*ATR[1];
   if(slpoints==NULL && SlATR>0) slpoints = Ask-SlATR*ATR[1];
   
   PositionSize();
   trade.Buy(Lot, _Symbol, Ask, slpoints, tppoints, text);
}

void ExecuteSell(double slpoints=NULL, double tppoints=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(tppoints==NULL && Mode==0 && TpATR2>0) tppoints = Bid-TpATR2*ATR[1];
   if(slpoints==NULL && SlATR>0) slpoints = Bid+SlATR*ATR[1];
   
   PositionSize();
   trade.Sell(Lot, _Symbol, Bid, slpoints, tppoints, text);
}

void ExecuteBuyStop(double entry, double sl=NULL, double tp=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask>entry) return;
   double _sl = sl;
   double _tp = tp;
   
   if(sl==NULL && SlATR>0) _sl=entry-SlATR*ATR[1];
   if(tp==NULL && TpATR1>0 && Mode==0) _tp=entry+TpATR1*ATR[1];
   PositionSize();
   trade.BuyStop(Lot, entry, _Symbol, _sl, _tp, NULL, NULL, text);
   
}

void ExecuteSellStop(double entry, double sl=NULL, double tp=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(Bid<entry) return;
   double _sl = sl;
   double _tp = tp;
   
   if(sl==NULL && SlATR>0) _sl=entry+SlATR*ATR[1];
   if(tp==NULL && TpATR2>0 && Mode==0) _tp=entry-TpATR2*ATR[1];
   PositionSize();
   trade.SellStop(Lot, entry, _Symbol, _sl, _tp, NULL, NULL, text);
}

void CheckPositions(){     
   buyPosition=0;
   sellPosition=0;
   buyDuration = -1;
   sellDuration = -1;
   
   ulong _ticket;
   
   for(int i=0; i<OrdersTotal(); i++){
      _ticket = OrderGetTicket(i);
         
      if(OrderSelect(_ticket)){
         if(OrderGetInteger(ORDER_MAGIC) == Magic && OrderGetString(ORDER_SYMBOL) == _Symbol){
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT){
               buyPosition+=1;
            }
            else if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP ||OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT){
               sellPosition+=1;
            }
         }
      }
   }
   
   for(int i=0; i<PositionsTotal(); i++){
      _ticket = PositionGetTicket(i);
      
      if(PositionSelectByTicket(_ticket)){
         if(PositionGetInteger(POSITION_MAGIC) == Magic && PositionGetString(POSITION_SYMBOL) == _Symbol){
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
               buyPosition+=1;
               buyDuration = iBarShift(_Symbol, PERIOD_D1, PositionGetInteger(POSITION_TIME), false);
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               sellPosition+=1;
               sellDuration = iBarShift(_Symbol, PERIOD_D1, PositionGetInteger(POSITION_TIME), false);
            }
         }
      }
   }
   
   if(ArraySize(ATR)>1) Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration, "\nATR: ", NormalizeDouble(ATR[1], 3));
   else Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration);
}

void TimeExit(){
   if(buyDuration>=TimeExit1 && TimeExit1>=0) ClosePosition(POSITION_TYPE_BUY);
   if(sellDuration>=TimeExit2 && TimeExit2>=0) ClosePosition(POSITION_TYPE_SELL);
}

void ClosePosition(ENUM_POSITION_TYPE _type){
   int _closed = 0;
   int i;
   ulong _ticket;
   int total = PositionsTotal();
   for(int j =0; j<total; j++)
   {
      i = j-_closed;      
      _ticket = PositionGetTicket(i);
      
      if (PositionSelectByTicket(_ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && PositionGetString(POSITION_SYMBOL)== _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE) == _type)
            {
               trade.PositionClose(_ticket);
               _closed +=1;
            }
         }
      }
   }
}

void CloseOrder(ENUM_ORDER_TYPE _type){
   int _closed = 0;
   int i;
   ulong _ticket;
   int total = OrdersTotal();
   for(int j =0; j<total; j++)
   {
      i = j-_closed;      
      _ticket = OrderGetTicket(i);
      
      if (OrderSelect(_ticket))
      {
         if (OrderGetInteger(ORDER_MAGIC)==Magic && OrderGetString(ORDER_SYMBOL)== _Symbol)
         {
            if(OrderGetInteger(ORDER_TYPE) == _type)
            {
               trade.OrderDelete(_ticket);
               _closed +=1;
            }
         }
      }
   }
}

bool InProfit(ENUM_POSITION_TYPE type){
   ulong _ticket;
   double _profitMargin;
   
   for(int i=0; i<PositionsTotal(); i++){
      _ticket = PositionGetTicket(i);
      
      if (PositionSelectByTicket(_ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){
               _profitMargin = PositionGetDouble(POSITION_PRICE_CURRENT)-PositionGetDouble(POSITION_PRICE_OPEN);
               TriggerATR=TpATR1;
            }
            else{
               _profitMargin = PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_PRICE_CURRENT);
               TriggerATR=TpATR2;
            }
            
            if(type == PositionGetInteger(POSITION_TYPE) && _profitMargin>TriggerATR*ATR[1]){
               return true;
            }
         }
      }
   }
   return false;
}

void ProcessPosition(){ 
   if(TriggerATR<0 || Mode==0) return;
   
   if(InProfit(POSITION_TYPE_BUY)){
      ClosePosition(POSITION_TYPE_BUY);
   }
   if(InProfit(POSITION_TYPE_SELL)){
      ClosePosition(POSITION_TYPE_SELL);
   }
}

void Range(int bars){
   if(bars<=0) return; 
   
   Highest = iHigh(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_HIGH, bars, 2));
   Lowest = iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW, bars, 2));
   
   if(Highest!=oldHigh){
      ObjectMove(0, "High", 0, 0, Highest);
      oldHigh = Highest;
   }
   if(Lowest!=oldLow){
      ObjectMove(0, "Low", 0, 0, Lowest);
      oldLow = Lowest; 
   }
}

void PlotNextDataPoint(double &customValues[])
{
  int arraySize = ArraySize(customValues);

  if (arrayIndex > 0 && arrayIndex < arraySize)
  {
    double previousValue = customValues[arrayIndex - 1];
    double currentValue  = customValues[arrayIndex];

    datetime previousDayTime = iTime(Symbol(), PERIOD_D1, 1);  // Previous day
    datetime currentDayTime  = iTime(Symbol(), PERIOD_D1, 0);  // Current day

    string objName = "LineSegment_" + IntegerToString(arrayIndex);
    ObjectCreate(0, objName, OBJ_TREND, 0, previousDayTime, previousValue, currentDayTime, currentValue);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrBlue);  
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);        
    arrayIndex++;
  }
  else if (arrayIndex == 0)
  {
    arrayIndex++;
  }
  else
  {
    Print("All points in the array have been plotted.");
  }
}