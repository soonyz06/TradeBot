#include<Trade\Trade.mqh>
CTrade trade;

input group "===   Inputs   ===";
input ulong Magic = 122;
input ENUM_TIMEFRAMES Timeframe = PERIOD_D1;
input double _R = 1; //FixedRisk
double FixedRisk;
double VariableRisk;
double MinLot;
double Lot;
int Mode;
double initial_balance;
input string Note = "";

input group "===   Settings   ===";
input double threshold = 0.2;
double TpATR=-1; //TP 
double SlATR=-1; //SL 
int TimeExit; //Time Exit
input int Lookback = 10; 
double ret; //Retracement 
double TriggerATR;
int atr_len;
int Spread;

input group "===   Time   ===";
input int A = 16; //Start Time 
int B; //Stop Time
int Z; //Exit Time
int E; //Expiration Time
//16:30-23:00

//Variables
string today;
string yesterday;
datetime Start;
datetime Stop;
datetime Exit;
datetime Expiration;
string Trade_Start; //Start Time
string Trade_Stop; //Stop Time
string Trade_Exit; //Exit Time
string Trade_Expiration; //Expiration Time
int bar1;
int bar2;
int newbar;
int newbar2;
string text;
int buyPosition;
int sellPosition;
int buyDuration;
int sellDuration;

MqlRates Price[];
double High[];
double Low[];
double Highest;
double Lowest;
double oldHigh;
double oldLow;
double ATR[];
int ATRHandler;



//---------------------------------------------------------------------------------------------------------



void OnInit(){
   FixedRisk = _R/100;
   VariableRisk = 0;
   MinLot = 0.1;
   atr_len = 50;
   
   if(MinLot<0.1){
      B = 20; //Stop TIme
      Z = 20; //Exit Time
      E = B; //Expiration Time
   }
   else{
      B = 22;
      Z = 22; 
      E = B; 
   }
   
   TimeExit = 0;
   ret = 0.1;
   TriggerATR = TpATR;
   Trade_Start= string(A)+":35:00"; 
   Trade_Stop = string(B)+":00:00"; 
   Trade_Exit = string(Z)+":00:00"; 
   Trade_Expiration = string(E)+":00:00"; 
   buyDuration =-1;
   sellDuration =-1;
   Highest = 0;
   Lowest = DBL_MAX;
   Mode = 0;
   
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
   ATRHandler = iATR(_Symbol, Timeframe, atr_len);
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


   newbar = iBars(_Symbol, Timeframe);
   if(bar1!=newbar){ 
      if(TimeCurrent()>=Start && TimeCurrent()<Expiration){
         Range(Lookback);
         CheckPositions();
         
         if(buyPosition==0 && Highest/Lowest-1 > threshold)
            ExecuteBuyStop(Highest, Lowest);
         else
            PositionModify(POSITION_TYPE_BUY, Lowest);
         bar1=newbar;
      }
   }
}



//---------------------------------------------------------------------------------------------------------



void PositionSize(double SL){
   double _Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(VariableRisk<=0 && FixedRisk<=0){
      Lot = MinLot;
   }
   else if(MinLot<0.1)
   {
      double slpoints;
      if(SlATR<0) slpoints = _Ask; else slpoints = SL/_Point;
      string Curr1 = StringSubstr(_Symbol, 0, 3);
      string Curr2 = StringSubstr(_Symbol, 3, 3);
      if(FixedRisk>0){
         Lot = initial_balance*FixedRisk/slpoints;
      }
      else{
         int _rounded_balance = int(AccountInfoDouble(ACCOUNT_BALANCE)/10)*10;
         Lot = _rounded_balance*VariableRisk/slpoints;
      }
      if (Curr2 == "USD"){
         
      }
      else if(Curr2=="JPY"){
         double Ask2 = NormalizeDouble(SymbolInfoDouble("USD"+Curr2, SYMBOL_ASK), _Digits);
         Lot = Lot*Ask2/100;
      }
      else{
         double Ask2 = NormalizeDouble(SymbolInfoDouble("USD"+Curr2, SYMBOL_ASK), _Digits);
         double Bid2 = NormalizeDouble(SymbolInfoDouble(Curr2+"USD", SYMBOL_BID), _Digits);
         Lot = Lot*Ask2;
         if(Lot==0)
            Lot = Lot/Bid2;
      }
      Lot = MathRound(Lot/MinLot)*MinLot;
   }
   else{
      if(SlATR<0) SL = _Ask; 
      if(FixedRisk>0){
         Lot = MathRound((initial_balance*FixedRisk)/(SL)/MinLot)*MinLot;
      }
      else{
         int _rounded_balance = int(AccountInfoDouble(ACCOUNT_BALANCE)/10)*10;
         Lot = MathRound((_rounded_balance*VariableRisk)/(SL)/MinLot)*MinLot;
      }
   }
   if(Lot<MinLot) Lot=MinLot;
   if(Lot>1000) Lot=1000;
}

void ExecuteBuyStop(double entry, double sl=NULL, double tp=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask>entry) return;
   if(entry-Ask<ATR[1]*ret) return;
   double _sl = sl;
   double _tp = tp;
   
   if(sl==NULL && SlATR>0) _sl=entry-SlATR*ATR[1];
   if(tp==NULL && TpATR>0) _tp=entry+TpATR*ATR[1];
   PositionSize(_sl);
   trade.BuyStop(Lot, entry, _Symbol, _sl, _tp, ORDER_TIME_SPECIFIED, Expiration, text);
}

void ExecuteSellStop(double entry, double sl=NULL, double tp=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(Bid<entry) return;
   if(Bid-entry<ATR[1]*ret) return;
   double _sl = sl;
   double _tp = tp;
   
   //if(sl==NULL && SlATR>0) _sl=entry+SlATR*ATR[1];
   //if(tp==NULL && TpATR>0) _tp=entry-TpATR*ATR[1];
   PositionSize(_sl);
   trade.SellStop(Lot, entry, _Symbol, _sl, _tp, ORDER_TIME_SPECIFIED, Expiration, text);
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
               buyDuration = iBarShift(_Symbol, PERIOD_D1, datetime(PositionGetInteger(POSITION_TIME)), false);
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               sellPosition+=1;
               sellDuration = iBarShift(_Symbol, PERIOD_D1, datetime(PositionGetInteger(POSITION_TIME)), false);
            }
         }
      }
   }
   
   //double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   //double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   //Spread = int(MathRound((Ask-Bid)/_Point));
   //if(ArraySize(ATR)>1) Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration, "\nATR: ", NormalizeDouble(ATR[1], 3), "\nSpread: ", Spread, " points \n", Note);
   //else Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration, "\nSpread: ", Spread, " points \n", Note);
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
               //TriggerATR=0;
            }
            else{
               _profitMargin = PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_PRICE_CURRENT);
               //TriggerATR=0;
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
   
   CopyHigh(_Symbol, Timeframe, 1, bars, High);
   CopyLow(_Symbol, Timeframe, 1, bars, Low);
   Highest = NormalizeDouble(High[ArrayMaximum(High, 0, WHOLE_ARRAY)], _Digits);
   Lowest = NormalizeDouble(Low[ArrayMinimum(Low, 0, WHOLE_ARRAY)], _Digits);
   
   //double _Close[];
   //double _Open[];
   //CopyClose(_Symbol, Timeframe, 1, bars, _Close);
   //CopyOpen(_Symbol, Timeframe, 1, bars, _Open);
   //Highest = MathMax(NormalizeDouble(_Close[ArrayMaximum(_Close, 0, WHOLE_ARRAY)], _Digits), NormalizeDouble(_Open[ArrayMaximum(_Open, 0, WHOLE_ARRAY)], _Digits));
   //Lowest = MathMin(NormalizeDouble(_Close[ArrayMinimum(_Close, 0, WHOLE_ARRAY)], _Digits), NormalizeDouble(_Open[ArrayMinimum(_Open, 0, WHOLE_ARRAY)], _Digits));
   
   
   if(Highest!=oldHigh){
      ObjectMove(0, "High", 0, 0, Highest);
      oldHigh = Highest;
      CloseOrder(ORDER_TYPE_BUY_STOP);
   }
   if(Lowest!=oldLow){
      ObjectMove(0, "Low", 0, 0, Lowest);
      oldLow = Lowest; 
      CloseOrder(ORDER_TYPE_SELL_STOP);
   }
}

void PositionModify(ENUM_POSITION_TYPE type, double sl){
   for(int i =0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      if (PositionSelectByTicket(ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE) == type)
            {
               if((type == POSITION_TYPE_BUY && sl>PositionGetDouble(POSITION_SL)) || (type == POSITION_TYPE_SELL && (sl<PositionGetDouble(POSITION_SL) || PositionGetDouble(POSITION_SL)==0)))
               trade.PositionModify(ticket, sl, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}