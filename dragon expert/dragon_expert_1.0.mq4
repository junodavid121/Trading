//+------------------------------------------------------------------+
//|                                      Strategy: Dragon_expert.mq4 |
//|                                       Created with Chinese Forex |
//+------------------------------------------------------------------+
#property copyright "chinese forex"
#property version   "1.0"
#property description "run in any time frame"

#include <stdlib.mqh>
#include <stderror.mqh>

extern int MagicNumber = 12345679;
extern double Init_lot = 0.1;
extern double distance = 10;  //in pips
extern double take_profit = 8;  //in pips
extern double Martin_factor = 1.5;
extern double SL_in_dollar = 1000; // Sl in monetary value

int MaxSlippage = 10;
int LotDigits; //initialized in OnInit
bool crossed[4]; //initialized to true, used in function Cross
int OrderRetry = 5; //# of retries if sending order returns error
int OrderWait = 5; //# of seconds to wait if sending order returns error
double myPoint; //initialized in OnInit

//+------------------------------------------------------------------+
//| functions                                                        |
//+------------------------------------------------------------------+
// Alert
void myAlert(string type, string message)
  {
   if(type == "print")
      Print(message);
   else
      if(type == "error")
        {
        }
      else
         if(type == "order")
           {
           }
         else
            if(type == "modify")
              {
              }
  }
//----------------------------------------------------------------------------------------------
// count number of trades
int TradesCount(int type) //returns # of open trades for order type, current symbol and magic number
  {
   int result = 0;
   int total = OrdersTotal();
   for(int i = 0; i < total; i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
         continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol() || OrderType() != type)
         continue;
      result++;
     }
   return(result);
  }
//----------------------------------------------------------------------------------------------
// find last trade price ; (1) long ; (-1) short
double LastTradePrice(int direction)
  {
   double result = 0;
   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderType() > 1)
         continue;
      if((direction < 0 && OrderType() == OP_BUY) || (direction > 0 && OrderType() == OP_SELL))
         continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
        {
         result = OrderOpenPrice();
         break;
        }
     }
   return(result);
  }
//----------------------------------------------------------------------------------------------
// find last trade lot size ; (1) long ; (-1) short
double LastTradeLots(int direction)
  {
   double result = 0;
   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderType() > 1)
         continue;
      if((direction < 0 && OrderType() == OP_BUY) || (direction > 0 && OrderType() == OP_SELL))
         continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
        {
         result = OrderLots();
         break;
        }
     }
   return(result);
  }
  //----------------------------------------------------------------------------------------------
// calculate total profit in each direction (1) long (-1 short)
double TotalOpenProfit(int direction)
  {
   double result = 0;
   int total = OrdersTotal();
   for(int i = 0; i < total; i++)   
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if((direction < 0 && OrderType() == OP_BUY) || (direction > 0 && OrderType() == OP_SELL)) continue;
      result += OrderProfit();
     }
   return(result);
  }
//----------------------------------------------------------------------------------------------
// calculate average long price
double PriceAverageLong()
{
   double PriceSum_long =0;
   double LotSum_long =0;
   int count=0;

      for (int i=0; i<OrdersTotal(); i++)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderSymbol()==Symbol() && OrderType()==OP_BUY)
      {
         PriceSum_long += OrderOpenPrice()*OrderLots();
         LotSum_long += OrderLots();
         count++;
      }
      }
   return(NormalizeDouble( (PriceSum_long)/(LotSum_long),Digits ));
}

//----------------------------------------------------------------------------------------------
// calculate average short price
double PriceAverageShort()
{
   double PriceSum_Short =0;
   double LotSum_Short =0;
   int count_sell=0;

      for (int i=0; i<OrdersTotal(); i++)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderSymbol()==Symbol() && OrderType()==OP_SELL)
      {
         PriceSum_Short += OrderOpenPrice()*OrderLots();
         LotSum_Short += OrderLots();
         count_sell++;
      }
      }
   return(NormalizeDouble( (PriceSum_Short)/(LotSum_Short),Digits ));
}
  
//----------------------------------------------------------------------------------------------
// Function to send order
int myOrderSend(int type, double price, double volume, string ordername) //send order, return ticket ("price" is irrelevant for market orders)
  {
   if(!IsTradeAllowed())
      return(-1);
   int ticket = -1;
   int retries = 0;
   int err = 0;
   int long_trades = TradesCount(OP_BUY);
   int short_trades = TradesCount(OP_SELL);
   int long_pending = TradesCount(OP_BUYLIMIT) + TradesCount(OP_BUYSTOP);
   int short_pending = TradesCount(OP_SELLLIMIT) + TradesCount(OP_SELLSTOP);
   string ordername_ = ordername;
   if(ordername != "")
      ordername_ = "("+ordername+")";
//prepare to send order
   while(IsTradeContextBusy())
      Sleep(100);
   RefreshRates();
   if(type == OP_BUY)
      price = Ask;
   else
      if(type == OP_SELL)
         price = Bid;
      else
         if(price < 0) //invalid price for pending order
           {
            myAlert("order", "Order"+ordername_+" not sent, invalid price for pending order");
            return(-1);
           }
   int clr = (type % 2 == 1) ? clrRed : clrBlue;
   while(ticket < 0 && retries < OrderRetry+1)
     {
      ticket = OrderSend(Symbol(), type, NormalizeDouble(volume, LotDigits), NormalizeDouble(price, Digits()), MaxSlippage, 0, 0, ordername, MagicNumber, 0, clr);
      if(ticket < 0)
        {
         err = GetLastError();
         myAlert("print", "OrderSend"+ordername_+" error #"+IntegerToString(err)+" "+ErrorDescription(err));
         Sleep(OrderWait*1000);
        }
      retries++;
     }
   if(ticket < 0)
     {
      myAlert("error", "OrderSend"+ordername_+" failed "+IntegerToString(OrderRetry+1)+" times; error #"+IntegerToString(err)+" "+ErrorDescription(err));
      return(-1);
     }
   string typestr[6] = {"Buy", "Sell", "Buy Limit", "Sell Limit", "Buy Stop", "Sell Stop"};
   myAlert("order", "Order sent"+ordername_+": "+typestr[type]+" "+Symbol()+" Magic #"+IntegerToString(MagicNumber));
   return(ticket);
  }
//----------------------------------------------------------------------------------------------
// function to close order
void myOrderClose(int type, int volumepercent, string ordername) //close open orders for current symbol, magic number and "type" (OP_BUY or OP_SELL)
  {
   if(!IsTradeAllowed())
      return;
   if(type > 1)
     {
      myAlert("error", "Invalid type in myOrderClose");
      return;
     }
   bool success = false;
   int err = 0;
   string ordername_ = ordername;
   if(ordername != "")
      ordername_ = "("+ordername+")";
   int total = OrdersTotal();
   int orderList[][2];
   int orderCount = 0;
   int i;
   for(i = 0; i < total; i++)
     {
      while(IsTradeContextBusy())
         Sleep(100);
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol() || OrderType() != type)
         continue;
      orderCount++;
      ArrayResize(orderList, orderCount);
      orderList[orderCount - 1][0] = OrderOpenTime();
      orderList[orderCount - 1][1] = OrderTicket();
     }
   if(orderCount > 0)
      ArraySort(orderList, WHOLE_ARRAY, 0, MODE_ASCEND);
   for(i = 0; i < orderCount; i++)
     {
      if(!OrderSelect(orderList[i][1], SELECT_BY_TICKET, MODE_TRADES))
         continue;
      while(IsTradeContextBusy())
         Sleep(100);
      RefreshRates();
      double price = (type == OP_SELL) ? Ask : Bid;
      double volume = NormalizeDouble(OrderLots()*volumepercent * 1.0 / 100, LotDigits);
      if(NormalizeDouble(volume, LotDigits) == 0)
         continue;
      success = OrderClose(OrderTicket(), volume, NormalizeDouble(price, Digits()), MaxSlippage, clrWhite);
      if(!success)
        {
         err = GetLastError();
         myAlert("error", "OrderClose"+ordername_+" failed; error #"+IntegerToString(err)+" "+ErrorDescription(err));
        }
     }
   string typestr[6] = {"Buy", "Sell", "Buy Limit", "Sell Limit", "Buy Stop", "Sell Stop"};
   if(success)
      myAlert("order", "Orders closed"+ordername_+": "+typestr[type]+" "+Symbol()+" Magic #"+IntegerToString(MagicNumber));
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//initialize myPoint
   myPoint = Point();
   if(Digits() == 5 || Digits() == 3)
     {
      myPoint *= 10;
      MaxSlippage *= 10;
     }
//initialize LotDigits
   double LotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   if(LotStep >= 1)
      LotDigits = 0;
   else
      if(LotStep >= 0.1)
         LotDigits = 1;
      else
         if(LotStep >= 0.01)
            LotDigits = 2;
         else
            LotDigits = 3;
   return(INIT_SUCCEEDED);
  }


//+------------------------------------------------------------------+
//| Determine Open & Close (tick function)                           |
//+------------------------------------------------------------------+
void OnTick()
 {
   int ticket = -1;
   double price;


//Open Buy Order
   if(TradesCount(OP_BUY) == 0 //open trade if there is no current order
     )
     {
      RefreshRates();
      price = Ask;
      if(IsTradeAllowed())
        {
         ticket = myOrderSend(OP_BUY, price, Init_lot, "first level long");
         if(ticket <= 0)
            return;
        }
      else //not autotrading => only send alert
         myAlert("order", "");
     }

//add buy Matrin order
   RefreshRates();
   if(LastTradePrice(1) - Ask >= distance * myPoint // last trade drops 10 (distance) pips
     )
     {
      RefreshRates();
      price = Ask;
      if(IsTradeAllowed())
        {
         ticket = myOrderSend(OP_BUY, price, LastTradeLots(1)* Martin_factor, "");
         if(ticket <= 0)
            return;
        }
      else //not autotrading => only send alert
         myAlert("order", "");
     }


   //Close Long Positions (TP)
   if(Bid - PriceAverageLong() >= take_profit * myPoint //Total Open Profit (Long) >= fixed value
     )
     {
      if(IsTradeAllowed())
         myOrderClose(OP_BUY, 100, "");
      else //not autotrading => only send alert
         myAlert("order", "");
     }
     
     
    //Close Long Positions (SL)
   if(TotalOpenProfit(1) <= -SL_in_dollar) //Account Balance >= Account Equity
     {   
      if(IsTradeAllowed())
         myOrderClose(OP_BUY, 100, "");
      else //not autotrading => only send alert
         myAlert("order", "");
     }
  
  
  //Open sell Order
   if(TradesCount(OP_SELL) == 0 //open trade if there is no current order
     )
     {
      RefreshRates();
      price = Bid;
      if(IsTradeAllowed())
        {
         ticket = myOrderSend(OP_SELL, price, Init_lot, "first level short");
         if(ticket <= 0)
            return;
        }
      else //not autotrading => only send alert
         myAlert("order", "");
     }
     
     //add sell Matrin order
   RefreshRates();
   if(Bid - LastTradePrice(-1) >= distance * myPoint // last trade drops 10 (distance) pips
     )
     {
      RefreshRates();
      price = Bid;
      if(IsTradeAllowed())
        {
         ticket = myOrderSend(OP_SELL, price, LastTradeLots(-1)* Martin_factor, "");
         if(ticket <= 0)
            return;
        }
      else //not autotrading => only send alert
         myAlert("order", "");
     }
     
     //Close Short Positions (TP)
   if(PriceAverageShort() - Ask >= take_profit * myPoint //Total Open Profit (Long) >= fixed value
     )
     {
      if(IsTradeAllowed())
         myOrderClose(OP_SELL, 100, "");
      else //not autotrading => only send alert
         myAlert("order", "");
     }
     
     //Close Short Positions (SL)
   if(TotalOpenProfit(-1) <= -SL_in_dollar) //Account Balance >= Account Equity
     {   
      if(IsTradeAllowed())
         myOrderClose(OP_SELL, 100, "");
      else //not autotrading => only send alert
         myAlert("order", "");
     }


}
//+------------------------------------------------------------------+

