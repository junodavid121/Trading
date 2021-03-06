//+------------------------------------------------------------------+
//|                                        Strategy: IdeaPro_Adv.mq4 |
//|                                          Created with David Chen |
//+------------------------------------------------------------------+
#property copyright "David"
#property version   "2.02"
#property description "Change TP to point"

#include <stdlib.mqh>
#include <stderror.mqh>

extern int MagicNumber = 123;
extern double Profit_First = 200; //in pips
extern double Profit_After = 100; //in pips
extern double Breakeven_Order = 7;
extern double setStopLoss = 1000; // in dollar
extern double MM_Start = 0.01; 
extern double MM_Profit_Add = 2;
extern double MM_Profit_Factor = 1;
extern int Step = 300;
extern int MaxSlippage = 10;
extern double startOrderDis = 1200;
extern double endOrderDis = 0;
extern int periodInd = 50;
extern int AutoGrid = 100; 
int LotDigits; //initialized in OnInit
bool crossed[4]; //initialized to true, used in function Cross
int OrderRetry = 5; //# of retries if sending order returns error
int OrderWait = 5; //# of seconds to wait if sending order returns error


//+------------------------------------------------------------------+
//| Functions                                                        |
//+------------------------------------------------------------------+

//----------------------------------------------------------------------------------------------
// Alert Function
void myAlert(string type, string message)
  {
   if(type == "print")
      Print(message);
   else if(type == "error")
     {
      Print(type+" | test2 @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
     }
   else if(type == "order")
     {
     }
   else if(type == "modify")
     {
     }
  }

//----------------------------------------------------------------------------------------------
// Select Last Trade
bool SelectLastCurrentTrade(int type)
  {
   int lastOrder = -1;
   int total = OrdersTotal();
   //Count from last to most current
   for(int i = total-1; i >= 0; i--) // Select most current order, i is from total -1 to 0, array start from zero
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue; //Select from history, If function can not select order, skip the function.
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == type ) //If they have same symbol and same magic number, record the number and finish the function
        {
         lastOrder = i;
         //Break if there is an order
         break;
        }
     }
  //return true if there is an live order
   return(lastOrder >= 0);
  }

//----------------------------------------------------------------------------------------------
// Determine Lot size
double MM_Size(int type) 
  {
   double lots = MM_Start;
   if(SelectLastCurrentTrade(type))
     {
      double orderlots = OrderLots();
      lots = orderlots*MM_Profit_Factor + 0.01*MM_Profit_Add;
     }
   return(lots);
  }


//----------------------------------------------------------------------------------------------
//Cross function, Only send out one order
bool Cross(int i, bool condition) 
  {
   bool ret = condition && !crossed[i];
   crossed[i] = condition;
   return(ret);
  }

//----------------------------------------------------------------------------------------------
// count number of trades
int TradesCount(int type) 
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
// Change take profit in point
int auto_profit(int direction)
   {
      if(TradesCount(direction) >= Breakeven_Order)
      {
         return 5;
      }
      else if(TradesCount(direction) > 3)
      {
         return Profit_After;
      }
      else
      {
         return Profit_First;
      }

   }

//----------------------------------------------------------------------------------------------
// Calculate Average  price
double PriceAverage(int type)
{
   double PriceSum =0;
   double LotSum =0;
   int count=0;

   for (int i=0; i<OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))continue;
      if(OrderSymbol()==Symbol() && OrderType()== type && OrderMagicNumber() == MagicNumber)
      {
         PriceSum += OrderOpenPrice()*OrderLots();
         LotSum += OrderLots();
         count++;
      }
   }
   return(NormalizeDouble((PriceSum)/(LotSum),Digits));
}

//+------------------------------------------------------------------+
//| Determine Open & Close                                           |
//+------------------------------------------------------------------+

//----------------------------------------------------------------------------------------------
//Determine Buy Trades
bool determineOrder(int period, int type)
{
  double OrderPrice = OrderOpenPrice();
  
  if (type == OP_BUY)
  {
  //Buy if Ask price below MA line
    if(!SelectLastCurrentTrade(OP_BUY) && Cross(2, (iMA(NULL, PERIOD_CURRENT, period, 1, MODE_SMA, PRICE_CLOSE, 0)-Ask)>startOrderDis*0.00001))
    {
      return true;
    }
    //Add buy order if price going down
    else if(SelectLastCurrentTrade(OP_BUY))
    {
      if(OrderOpenPrice()- Ask >= 0.00001*Step && Ask - iLow(Symbol(),PERIOD_H1,0) >= 0.00001*AutoGrid)
      {
        return true;
      }
    }
  }
  else if(type == OP_SELL)
  {
    //Sell if Bid price above MA line
    if(!SelectLastCurrentTrade(OP_SELL) && Cross(3, (Bid - iMA(NULL, PERIOD_CURRENT, period, 1, MODE_SMA, PRICE_CLOSE, 0)>startOrderDis*0.00001)))
    {
      return true;
    }
    //Add sell order if price going up
    else if(SelectLastCurrentTrade(OP_SELL))
    {
      if( Bid - OrderOpenPrice() >= 0.00001*Step && iHigh(Symbol(),PERIOD_H1,0) - Bid >= 0.00001*AutoGrid)
      {
        return true;
      }
    }
  } 
  return false;
}



  
  
//----------------------------------------------------------------------------------------------
// Determine Close Trades
double determineClose(int period, int type)
{

  if(SelectLastCurrentTrade(type))
  {
     if(type == OP_BUY)
     {
       //Close Long Positions (TP)
      if(Bid - PriceAverage(OP_BUY) >= auto_profit(OP_BUY) * myPoint)//Total Open Profit (Long) >= fixed value
        {
         return true;
        }
       //Close buy orders based on indicator
      if(SelectLastCurrentTrade(type) && iMA(NULL, PERIOD_CURRENT, period, 1, MODE_SMA, PRICE_CLOSE, 0)-Ask < endOrderDis*0.00001)
       {
         return true;
       }
     }
     if(type == OP_SELL)
     {
       //Close Short Positions (TP)
       if(type == OP_SELL && PriceAverage(OP_SELL) - Ask >= auto_profit(OP_SELL) * myPoint)//Total Open Profit (Long) >= fixed value
       {
         return true;
       }
       //Close sell orders based on indicator
       if(SelectLastCurrentTrade(type) && Bid - iMA(NULL, PERIOD_CURRENT, period, 1, MODE_SMA, PRICE_CLOSE, 0) < endOrderDis*0.00001)
       {
         return true;
       }
     }
  }
  return false;
}

//+------------------------------------------------------------------+
//| Send Order functions                                             |
//+------------------------------------------------------------------+
//----------------------------------------------------------------------------------------------
//Send Order
int myOrderSend(int type, double price, double volume, string ordername) //send order, return ticket ("price" is irrelevant for market orders)
  {
   //Initialise
   if(!IsTradeAllowed()) return(-1);
   int ticket = -1;
   int retries = 0;
   int err = 0;
   string ordername_ = ordername;
   if (ordername_ != "")
   {
      ordername_="("+ordername+")";
   }

   //Prepare to send order
   while(IsTradeContextBusy()) Sleep(100);
   RefreshRates();
   //Determine the price style
   if(type == OP_BUY)
      price = Ask;
   else if(type == OP_SELL)
      price = Bid;
  //Alert Error if price is less than zero, invalid price for pending order
   else if(price < 0)
     {
      myAlert("order", "Order"+ordername_+" not sent, invalid price for pending order");
	  return(-1);
     }
   int clr = (type % 2 == 1) ? clrRed : clrBlue;
  //Send Order, volume is autoMM
   while(ticket < 0 && retries < OrderRetry+1)
     {
      ticket = OrderSend(Symbol(), type, NormalizeDouble(volume, LotDigits), NormalizeDouble(price, Digits()), MaxSlippage, 0, 0, ordername, MagicNumber, 0, clr);
      //Prevent error
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
//Close all orders
void myOrderClose(int type, int volumepercent, string ordername) //close open orders for current symbol, magic number and "type" (OP_BUY or OP_SELL)
  {
   //Test is trade allow, system function
   if(!IsTradeAllowed()) return;
   if (type > 1)
     {
      myAlert("error", "Invalid type in myOrderClose");
      return;
     }
  //Initial ticket sucess, Total orders, Order List, Order count.
   bool success = false;
   int err = 0;
   string ordername_ = ordername;
   if (ordername_ != "")
   {
      ordername_="("+ordername+")";
   }

   int total = OrdersTotal();
   int orderList[][2];
   int orderCount = 0;
   int i;
   for(i = 0; i < total; i++)
     {
      while(IsTradeContextBusy()) Sleep(100);
      //Select the order required
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      //If the Magic number of the order is not the same, Skip if the symbol, magicnumber or type of order is not the same
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol() || OrderType() != type) continue;
      //Count all the orders
      orderCount++;
      //Resize array and add order list, assign ticket number to array list [1]
      ArrayResize(orderList, orderCount);
      orderList[orderCount - 1][0] = OrderOpenTime();
      orderList[orderCount - 1][1] = OrderTicket();
     }
  //Sort Array from 0, small to large
   if(orderCount > 0)
      ArraySort(orderList, WHOLE_ARRAY, 0, MODE_ASCEND);
  //Close Order
   for(i = 0; i < orderCount; i++)
     {
      //Select the orders in the order list
      if(!OrderSelect(orderList[i][1], SELECT_BY_TICKET, MODE_TRADES)) continue;
      while(IsTradeContextBusy()) Sleep(100);
      RefreshRates();
      //Assign price
      double price = (type == OP_SELL) ? Ask : Bid;
      //Around the volume to digit, use current lot size.
      double volume = NormalizeDouble(OrderLots()*volumepercent * 1.0 / 100, LotDigits);
      //if volume is zero, skip the order close process
      if (NormalizeDouble(volume, LotDigits) == 0) continue;
      //Order close
      success = OrderClose(OrderTicket(), volume, NormalizeDouble(price, Digits()), MaxSlippage, clrWhite);
      //If no ticket number return, alert error
      if(!success)
        {
         err = GetLastError();
         myAlert("error", "OrderClose"+ordername_+" failed; error #"+IntegerToString(err)+" "+ErrorDescription(err));
        }
     }
  }


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
  //initialize myPoint
  double myPoint = Point();
  if(Digits() == 5 || Digits() == 3)
    {
    myPoint *= 10;
    MaxSlippage *= 10;
    }   
  //initialize LotDigits
   double LotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   if(LotStep >= 1) LotDigits = 0;
   else if(LotStep >= 0.1) LotDigits = 1;
   else if(LotStep >= 0.01) LotDigits = 2;
   else LotDigits = 3;
   return(INIT_SUCCEEDED);
   //initialize crossed
   for (int i = 0; i < ArraySize(crossed); i++)
      crossed[i] = true;
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   int ticket = -1;
   double price;   
   bool buyTrade = false;
   bool closeBuyTrade = false;
   bool sellTrade = false;
   bool closeSellTrade = false;
   
   buyTrade = determineOrder(periodInd,OP_BUY);
   closeBuyTrade = determineClose(periodInd,OP_BUY);
   sellTrade = determineOrder(periodInd,OP_SELL);
   closeSellTrade = determineClose(periodInd,OP_SELL);


   
   //Open Buy Order, instant signal is tested first (Open new order)
   if(buyTrade) 
     {
      RefreshRates();
      price = Ask;   
      if(IsTradeAllowed())
        {
         ticket = myOrderSend(OP_BUY, price, MM_Size(OP_BUY), "");
         if(ticket <= 0) return;
        }
      else
         myAlert("order", "");
     }

   //Open Sell Order, instant signal is tested first (Open new order)
   if(sellTrade)
     {
      RefreshRates();
      price = Bid;
      if(IsTradeAllowed())
        {
         ticket = myOrderSend(OP_SELL, price, MM_Size(OP_SELL), "");
         if(ticket <= 0) return;
        }
      else 
         myAlert("order", "");
     }
   
   RefreshRates();
   //Close Long Positions, instant signal is tested first (TP & SL)
   if(SelectLastCurrentTrade(OP_BUY)&& closeBuyTrade) 
     {   
      if(IsTradeAllowed())
         myOrderClose(OP_BUY, 100, "");
      else 
         myAlert("order", "");
     }

   //Close Short Positions, instant signal is tested first (TP & SL)
   if(SelectLastCurrentTrade(OP_SELL)&&closeSellTrade) 
     {   
      if(IsTradeAllowed())
         myOrderClose(OP_SELL, 100, "");
      else 
         myAlert("order", "");
     }

   }
//+------------------------------------------------------------------+