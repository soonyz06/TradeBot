#include<Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+

///Variables
input ulong Magic = 2100;
input double FixedLot = 0; 
input double risk = 0.005; //Risk
input int A = 4; //Range Start 
input int B = 8; //Trade Start
input int D = 20; //Trade End
input int F = 1; //Trade Duration
int E = B+F; //Expiration
input int x = 1000; //Band-Max
//input int T = 1; //Trade-Limiter
int o = 15;

string Dorm_Start = string(A)+":00:00";
string Dorm_Stop = string(B)+":00:00";
string Trade_Start = string(B)+":00:00";
string Trade_Stop = string(D)+":00:00";
string Expiration_ = string(E)+":00:00";
double Lot;
double SlPoints;
int Position;
double Max;
double Min;

//+------------------------------------------------------------------+

string day;
int bar;
int newbar;
string yesterday;
datetime Start; 
datetime Stop;
datetime TradeStart;
datetime TradeStop;
datetime Expiration;
string text; 
int done;
int buyPosition;
int sellPosition;
double dp;
int dpt[6];
int dpw[6];
double dpm[6];
int oldposition;
int newposition;
double profit = 0;

///Initialise
void OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   bar = 0;
   yesterday = "0";
   text = "RB"+string(Magic);
   //Line
   ObjectCreate(0, "Max", OBJ_HLINE, 0, _Period, 0);
   ObjectSetInteger(0, "Max", OBJPROP_COLOR, clrWhite);
   ObjectCreate(0, "Min", OBJ_HLINE, 0, _Period, 0);
   ObjectSetInteger(0, "Min", OBJPROP_COLOR, clrWhite);
   Comment("ID: ", Magic);
   oldposition = 0;
}
//+------------------------------------------------------------------+

void OnDeinit(const int reason){
   displayData();
}

//+------------------------------------------------------------------+

///Start
void OnTick()
{   
   //Spread
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   //Comment("ID: ", Magic, "\nSpread: ", int((Ask-Bid)/_Point));
   ///Time
   datetime now = TimeCurrent();
   string today = TimeToString(now, TIME_DATE);
   if(today != yesterday){
      ///MT4 time + 5 -> Malaysia Time
      Start = StringToTime(today+" "+Dorm_Start);
      Stop = StringToTime(today+" "+Dorm_Stop);
      TradeStart = StringToTime(today+" "+Trade_Start);
      TradeStop = StringToTime(today+" "+Trade_Stop);
      Expiration = StringToTime(today+" "+Expiration_);
      done = 0;
      yesterday = today;
   } 
   
   //+------------------------------------------------------------------+
   
   ///Range
   double Top[];
   ArraySetAsSeries(Top, true);
   CopyHigh(_Symbol, PERIOD_M15, Start, Stop, Top);
   double Low[];
   ArraySetAsSeries(Low, true);
   CopyLow(_Symbol, PERIOD_M15, Start, Stop, Low);
   
   //+------------------------------------------------------------------+
   
   if (ArraySize(Top)>0 && ArraySize(Low)>0)
   {
      //Line
      Max =  Top[ArrayMaximum(Top, 0, WHOLE_ARRAY)];
      Min = Low[ArrayMinimum(Low, 0, WHOLE_ARRAY)];
      ObjectMove(0, "Max", 0, _Period, Max);
      ObjectMove(0, "Min", 0, _Period, Min);
   
      //Box
      ObjectCreate(0, "Range", OBJ_RECTANGLE, 0, Start, Max, Stop, Min);
      ObjectSetInteger(0, "Range", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, "Range", OBJPROP_FILL, true);
      ObjectSetInteger(0, "Range", OBJPROP_BACK, true);
      
      ///Live
      newbar = iBars(_Symbol, PERIOD_M15);
      if(bar!=newbar){
         if((now>TradeStart && now<TradeStop) && done ==0){
            checkPositions();
            if(buyPosition == 0){
               executeBuy(Max+o*_Point);
            }
            if(sellPosition == 0){
               executeSell(Min-o*_Point);
            }
            
            if(buyPosition==1 && sellPosition==1){
               done =1;
            }
            
            
         }
         bar = newbar;
      }
     
    //+------------------------------------------------------------------+ 
   }
   
   //Comments
   //Comment(dpw[0], dpt[0], "\n",dpw[1], dpt[1], "\n",dpw[2], dpt[2], "\n",dpw[3], dpt[3], "\n",dpw[4], dpt[4], "\n",dpw[5], dpt[5], "\n");
   //Comment(dpm[0], "\n", dpm[1], "\n", dpm[2], "\n", dpm[3], "\n", dpm[4], "\n", dpm[5], "\n");
   
   checkPositions();
   if (oldposition!=newposition){
      if(newposition>oldposition){
         data(dpt);
         
         
      }
      oldposition = newposition;
   }
   
   //Close Trades
   if (now>TradeStop)
   {
      if(buyPosition>0 || sellPosition>0){
         if(checkProfit()){
            data(dpw);
            dataM();
         }
         closeAllPositions(); 
      }
      
   }
   
   //ObjectCreate(0, "Mid", OBJ_HLINE, 0, _Period, ((Max+Min)/2));
      
}

//+------------------------------------------------------------------+

///Functions
void closeAllPositions()
   {
      for (int i=PositionsTotal()-1; i>=0; i--)
      {  
         ulong ticket = PositionGetTicket(i);
         if (PositionSelectByTicket(ticket))
         {
            string symbol = PositionGetSymbol(i);
            if (PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol)
            {
               trade.PositionClose(ticket);
            }
         }
      }
   }

void checkPositions()
{
   buyPosition = 0;
   sellPosition = 0;
   newposition = 0;
   for(int i =0; i<OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      string symbol = OrderGetString(ORDER_SYMBOL);
      if (OrderSelect(ticket))
      {
         if (OrderGetInteger(ORDER_MAGIC)==Magic && symbol == _Symbol)
         {
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP)
            {
               buyPosition+=1;
            }
            else if(OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_SELL_STOP)
            {
               sellPosition+=1;
            }
         }
      }
   }
   for(int i =0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      if (PositionSelectByTicket(ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
            {
               buyPosition+=1;
               newposition+=1;
            }
            else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
            {
               sellPosition+=1;
               newposition+=1;
            }
         }
      }
   }
}

void positionSize(double slpoints)
{
   if(FixedLot == 0)
   {
      string symbol = _Symbol;
      string Curr1 = StringSubstr(symbol, 0, 3);
      string Curr2 = StringSubstr(symbol, 3, 3);
      double balance;
      //Comment(Curr1);
      if (Curr2 == "USD")
      {
         balance = AccountInfoDouble(ACCOUNT_BALANCE);
         Lot = balance*risk/slpoints;
      }
      else if (Curr2=="JPY")
      {
         double Ask2 = NormalizeDouble(SymbolInfoDouble("USD"+Curr2, SYMBOL_ASK), _Digits);
         balance = AccountInfoDouble(ACCOUNT_BALANCE);
         Lot = balance*risk/slpoints*Ask2/100;
      }
      else 
      {
         //USDCHF etc
         double Ask2 = NormalizeDouble(SymbolInfoDouble("USD"+Curr2, SYMBOL_ASK), _Digits);
         balance = AccountInfoDouble(ACCOUNT_BALANCE);
         Lot = balance*risk/slpoints*Ask2;
         //NZDUSD etc
         if(Lot==0)
         {
            double Bid2 = NormalizeDouble(SymbolInfoDouble(Curr2+"USD", SYMBOL_BID), _Digits);
            balance = AccountInfoDouble(ACCOUNT_BALANCE);
            Lot = balance*risk/slpoints/Bid2;
         }
      }
      if (Lot<0.01)
      {
         Lot = 0.01;
      }
      else if(MathIsValidNumber(Lot) == false)
      {
         balance = AccountInfoDouble(ACCOUNT_BALANCE);
         Lot = NormalizeDouble(balance*risk/slpoints, 1);
      }
      Lot = NormalizeDouble(Lot, 2);
   }
   else
   {
      Lot = FixedLot;
   }
}

void executeBuy(double entry){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   SlPoints = NormalizeDouble((Max-Min)/2*(1/_Point), 2);
   
    if(SlPoints<100 || SlPoints>900){ 
    //if(SlPoints<50){
      buyPosition +=1;
      return;
   } 
   
   dp = SlPoints;
   
   double Sl;
   if(SlPoints>x){
      SlPoints = 300;
      Sl = NormalizeDouble(entry-SlPoints*_Point, _Digits);
   }
   else{
      //SlPoints = y;
      //Sl = NormalizeDouble(entry-SlPoints*_Point, _Digits);
      Sl = NormalizeDouble(entry-((Max - Min)/2), _Digits);
   }
 
   positionSize(SlPoints);
   trade.BuyStop(Lot, entry, _Symbol, Sl, NULL, ORDER_TIME_SPECIFIED, Expiration, text);;
   
}

void executeSell(double entry){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   SlPoints = NormalizeDouble((Max-Min)*(1/_Point), 2);
   
   if(SlPoints<100 || SlPoints>900){ 
   //if(SlPoints<50){
      sellPosition +=1;
      return;
   } 
   
   dp = SlPoints;
   
   double Sl;
   if(SlPoints>x){
      SlPoints = 300;
      Sl = NormalizeDouble(entry+SlPoints*_Point, _Digits);  
   }
   else{
      //SlPoints = y;
      //Sl = NormalizeDouble(entry+SlPoints*_Point, _Digits);  
      Sl = NormalizeDouble(entry+((Max - Min)), _Digits);
   }
 
   positionSize(SlPoints);
   trade.SellStop(Lot, entry, _Symbol, Sl, NULL, ORDER_TIME_SPECIFIED, Expiration, text);
   
}


void data(int & dps[]){
   if(dp==0) return;
      
      if(dp<200){ 
         dps[0]+=1;
      }
      else if (dp<300){ 
         dps[1]+=1;
      }
      else if(dp<500){ 
         dps[2]+=1;
      }
      else if(dp<700){ 
         dps[3]+=1;
      }
      else if(dp<900){ 
         dps[4]+=1;
      }
      else if(dp>900){ 
         dps[5]+=1;
      }  
}

void dataM(){
   if(dp==0) return;
   
      checkProfit();
      if(dp<200){ 
         dpm[0]+=profit;
      }
      else if (dp<300){ 
         dpm[1]+=profit;
      }
      else if(dp<500){ 
         dpm[2]+=profit;
      }
      else if(dp<700){ 
         dpm[3]+=profit;
      }
      else if(dp<900){ 
         dpm[4]+=profit;
      }
      else if(dp>900){ 
         dpm[5]+=profit;
      }  
}

void displayData(){
   double output;
   for (int i = 0; i<6 ; i++){
      if(dpt[i]==0){
         Print("No Trades\n");
      }
      else{
         output = NormalizeDouble(dpw[i]*100/dpt[i], 1);
         Print("Revenue: ", NormalizeDouble(dpm[i], 1), " $");
         Print("WR: ", output, " %");
         Print("Weight: ", NormalizeDouble(output*dpm[i], 1));
         Print("Trades: ", dpt[i],"\n");
      }
      
   }
   
   //Print(dpw[0], dpt[0], "\n",dpw[1], dpt[1], "\n",dpw[2], dpt[2], "\n",dpw[3], dpt[3], "\n",dpw[4], dpt[4], "\n");
}

bool checkProfit()
{
   bool b;
      
   b = false;
   profit = 0;
   for(int i =0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      if (PositionSelectByTicket(ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol)
         {
            if(PositionGetDouble(POSITION_PROFIT)>0){
               b = true;
               profit = NormalizeDouble(PositionGetDouble(POSITION_PROFIT), 2);
            }
         }
      }
   }
   
   return b;
}