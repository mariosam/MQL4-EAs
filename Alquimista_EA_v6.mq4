//+------------------------------------------------------------------+
//|                                             Alquimista_EA_v6.mq4 |
//|                                                        Mario SAM |
//|                                         https://mariosam.com.br/ |
//+------------------------------------------------------------------+
//+ NOVIDADES V2:
//+   - zerado valor do TS para desligar o trailing stop
//+   - entra comprando/vendendo quando valor esta muito valorizado em M1
//+   - sai da operacao quando preco comeca a reverter em M1
//+ NOVIDADES V3:
//+   - alterado periodos de CCI de M1 para M15
//+ NOVIDADES V4:
//+   - incluido opcao de stop loss e take profit
//+   - alterado CCI M15 de entrada de 100 para 200
//+ NOVIDADES V5:
//+   - alterado saida de operacao para quando fizer curva de reversao em CCI
//+ NOVIDADES V6:
//+   - alterado saida de operacao para quando fizer curva de reversao em CCI para 150
//+   - alterado entrada, agora entra na curva do CCI
//+------------------------------------------------------------------+

#property copyright "by SAM"
#property link      "https://mariosam.com.br/"

//===Globais configuraveis pelo usuario
extern double Lotes       = 1.0; //valor lote negociavel
extern int    MaxTrades   = 1;   //maximo de operacoes abertas
extern int    MagicNumber = 190; //identificar de operacoes do EA
extern int    TS          = 0;   //trailing stop para reduzir perdas e garantir lucros
extern int    SL          = 15;  //stop loss para reduzir perdas
extern int    TP          = 10;  //take profit para criar metas de lucro

//===Globais nao configuraveis
int ticket; //verifica se ordem foi executada com sucesso
bool ordemAbertaPar = false; //falso indica q esta habilitado a operar

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
    Print( "Inicio Alquimista_EA_v6" );
    
    Comment( "Alquimista_EA_v6 in Action" );
    
    return(0);  
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() {
    Print( "Fim Alquimista_EA_v6" );
    
    return(0);
}

//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {
    verificaOrdensAbertas();
    
    //se nao houve compra/venda nas verificacoes anteriores
    if ( ordemAbertaPar == false ) {
    
        if ( possuiMargemOperar() ) {
        
            //nao houve reversao entao verifica tendencia compra
            continuaComprando();
        
            //nao houve reversao entao verifica tendencia venda
            continuaVendendo();        
        }
    } else {
        trailingStop();
    }
            
    return(0);
}

//+------------------------------------------------------------------+

bool possuiMargemOperar() {
    double livrePraGastar = AccountFreeMargin(); //valor livre para novas operacoes
    double lotePraUsar = (Lotes * 1000); //base de calculo para saber quantos lotes estao disponiveis

    //se a margem livre em numero de lotes for maior ou igual ao numero de lotes por operacao    
    if ( (livrePraGastar/lotePraUsar) >= Lotes ) {
        return (true);
    }

    return (false);
}

void trailingStop() {
    for ( int i = 0; i < OrdersTotal(); i++ ) {
    
        //recupera informacoes da posicao aberta
        OrderSelect( i, SELECT_BY_POS );

        //se a ordem q esta em aberto pertence ao EA
        if ( OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber ) {
        
            double Stop;
                
            if ( TS > 0 ) {                            
                if ( OrderType() == OP_BUY ) {

                    if ( Bid-OrderOpenPrice() > Point*TS ) {
                        if ( OrderStopLoss() < Bid-Point*TS ) {
                            Stop = Bid-Point*TS;
                        }
                    }                     
                
                } else if ( OrderType() == OP_SELL ) {

                    if ( Ask+OrderOpenPrice() > Point*TS ) {
                        if ( OrderStopLoss() < Ask+Point*TS ) {
                            Stop = Ask+Point*TS;
                        }
                    }
                           
                }
            
                if ( Stop > 0.0 ) {
                    bool ticketModify = OrderModify( OrderTicket(), OrderOpenPrice(), Stop, OrderTakeProfit(), 0, CLR_NONE );

                    //verifica se ordem foi alterada ou se ocorreu erro.
                    if (! ticketModify ) {
                        Print("Erro no Trailing Stop #", GetLastError());
                    } else {
                        Print("Trailing Stop alterado para o Par: ", OrderTicket());
                    }
                }
            }

        }
    }
}

//+------------------------------------------------------------------+

void verificaOrdensAbertas() {
    //percorre lista de ordens abertas
    int pEA = 0;
    bool ticketModify;
    for ( int i = 0; i < OrdersTotal(); i++ ) {
    
        //recupera informacoes da posicao aberta
        OrderSelect( i, SELECT_BY_POS );

        //se a ordem q esta em aberto pertence ao EA
        if ( OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber ) {
            pEA = pEA + 1; //numero de ordens abertas para este par com este magicnumber

            //se for ordem aberta de compra
            if ( OrderType() == OP_BUY ) {
        
                //verifica se fecha pelo CCI
                if ( verificaCCIFechaCompra() ) {
                    Alert( Symbol(), " - Fechar COMPRA" );
        
                    //fecha ordem
                    ticketModify = OrderClose( OrderTicket(), OrderLots(), Bid, 5, CLR_NONE );

                    //verifica se ordem foi alterada ou se ocorreu erro.
                    if (! ticketModify ) {
                        Print("Erro no Close de Compra #", GetLastError());
                    } else {
                        Print("Close Compra para o Par: ", OrderTicket());
                    }
                                        
                    ordemAbertaPar = false;
                    Print("Ordem de compra fechada por sinal");
                }

            //se for ordem aberta de venda
            } else if ( OrderType() == OP_SELL ) {

                //verifica se fecha pelo CCI
                if ( verificaCCIFechaVenda() ) {
                    Alert( Symbol(), " - Fechar VENDA" );
        
                    //fecha ordem
                    ticketModify = OrderClose( OrderTicket(), OrderLots(), Ask, 5, CLR_NONE );

                    //verifica se ordem foi alterada ou se ocorreu erro.
                    if (! ticketModify ) {
                        Print("Erro no de Venda Close #", GetLastError());
                    } else {
                        Print("Close Venda para o Par: ", OrderTicket());
                    }
                
                    ordemAbertaPar = false;
                    Print("Ordem de venda fechada por sinal");
                }
            }
        }
    }
    
    //verifica se atingiu o numero de operacoes abertas permitida
    if ( pEA > MaxTrades || pEA == MaxTrades ) {
        ordemAbertaPar = true; //bloqueia entrada de novas operacoes
    } else {
        ordemAbertaPar = false; //libera par para nova operacao
    }
}

//+------------------------------------------------------------------+

//compra se o preco mostra continuidade de alta
//alterado v4: incluido opcao de stop loss e take profit
void continuaComprando() {
    if ( verificaCompraContinuada() ) {
        double stop;
        double profit;
        
        if ( SL > 0 ) { stop   = Ask-SL*Point; }        
        if ( TP > 0 ) { profit = Ask+TP*Point; }
        
        //executa ordem de compra
        ticket = OrderSend( Symbol(), OP_BUY, Lotes, Ask, 0, stop, profit, "Alquimista_EA_v6 COMPRA", MagicNumber, 3, Blue );
        
        //verifica se ordem foi executada
        if ( ticket < 0 ) {
            Print( "Ordem de compra falhou #", GetLastError() );
        } else {
            Alert( Symbol(), " - Sinal de COMPRA" );
            Print( "Ordem de compra para o par: ", Symbol() );
        }
    }
}

//vende se o preco mostra continuidade de baixa
//alterado v4: incluido opcao de stop loss e take profit
void continuaVendendo() {
    if ( verificaVendaContinuada() ) {
        double stop;
        double profit;
        
        if ( SL > 0 ) { stop   = Bid+SL*Point; }       
        if ( TP > 0 ) { profit = Bid-TP*Point; }
                
        //executa ordem de venda
        ticket = OrderSend( Symbol(), OP_SELL, Lotes, Bid, 0, stop, profit, "Alquimista_EA_v6 VENDA", MagicNumber, 3, Red );
        
        //verifica se ordem foi executada
        if ( ticket < 0 ) {
            Print( "Ordem de venda falhou #", GetLastError() );
        } else {
            Alert( Symbol(), " - Sinal de VENDA" );
            Print( "Ordem de venda para o par: ", Symbol() );
        }
    }
}

//+------------------------------------------------------------------+

//se o EMA20 nao apresenta curva de reversao de venda tendencia de alta
//e CCI indica alta sem sinal de reversao
//alterado v2: abre posicao se CCI em M1 mostra preco sobrevendido
//alterado v3: alterado periodo do CCI de M1 para M15
//             adicionado verificacao de ADX para indicar reversao
//alterado v4: alterado valor CCI de -100 para -200
//alterado v6: alterado CCI de -200 pra -150 e agora entra no retorno da curva
bool verificaCompraContinuada() {
    if ( iMA( Symbol(), PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE, 0 ) > iMA( Symbol(), PERIOD_H4, 40, 0, MODE_EMA, PRICE_CLOSE, 0 ) 
      && iADX( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, MODE_PLUSDI, 0 ) < iADX( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, MODE_MINUSDI, 0 )
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 1 ) < -150
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) > -150 ) {
        return (true);
    }
    
    if ( iMA( Symbol(), PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE, 0 ) > iMA( Symbol(), PERIOD_H4, 40, 0, MODE_EMA, PRICE_CLOSE, 0 ) 
      && iADX( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, MODE_PLUSDI, 0 ) < iADX( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, MODE_MINUSDI, 0 )
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 1 ) < -200
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) > -200 ) {
        return (true);
    }
    
    return (false);
}

//se o EMA20 nao apresenta curva de reversao de alta tendencia de baixa
//e CCI indica baixa sem sinal de reversao
//alterado v2: abre posicao se CCI em M1 mostra preco sobrecomprado
//alterado v3: alterado periodo do CCI de M1 para M15
//             adicionado verificacao de ADX para indicar reversao
//alterado v4: alterado valor CCI de 100 para 200
//alterado v6: alterado CCI de 200 pra 150 e agora entra no retorno da curva
bool verificaVendaContinuada() {
    if ( iMA( Symbol(), PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE, 0 ) < iMA( Symbol(), PERIOD_H4, 40, 0, MODE_EMA, PRICE_CLOSE, 0 ) 
      && iADX( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, MODE_PLUSDI, 0 ) > iADX( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, MODE_MINUSDI, 0 )
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 1 ) > 150
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) < 150 ) {
        return (true); 
    }
    
    if ( iMA( Symbol(), PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE, 0 ) < iMA( Symbol(), PERIOD_H4, 40, 0, MODE_EMA, PRICE_CLOSE, 0 ) 
      && iADX( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, MODE_PLUSDI, 0 ) > iADX( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, MODE_MINUSDI, 0 )
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 1 ) > 200
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) < 200 ) {
        return (true); 
    }
    
    return (false);
}

//+------------------------------------------------------------------+

//se CCI curvar indicando reversao
//alterado v2: sai quando CCI no periodo M1 indica queda, garantindo lucro
//alterado v3: periodo de M1 para M15
//alterado v5: sai da operacao quando estiver sobrecomprado e iniciar curva de reversao
//alterado v6: sai da operacao quando estiver sobrecomprado e iniciar curva de reversao
bool verificaCCIFechaCompra() {
    if ( iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) > 100 
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 1 ) > iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) ) {
        return (true);
    }

    if ( iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) > 150 
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 1 ) > iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) ) {
        return (true);
    }

    if ( iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) > 200 
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 1 ) > iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) ) {
        return (true);
    }
            
    return (false);
}

//se CCI curvar indicando reversao
//alterado v2: sai quando CCI no periodo M1 indica alta, garantindo lucro
//alterado v3: periodo de M1 para M15
//alterado v5: sai da operacao quando estiver sobrevendido e iniciar curva de reversao
//alterado v6: sai da operacao quando estiver sobrevendido e iniciar curva de reversao
bool verificaCCIFechaVenda() {
    if ( iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) < -100 
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 1 ) < iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) ) {
        return (true);
    }

    if ( iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) < -150 
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 1 ) < iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) ) {
        return (true);
    }

    if ( iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) < -200 
      && iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 1 ) < iCCI( Symbol(), PERIOD_M15, 14, PRICE_CLOSE, 0 ) ) {
        return (true);
    }
            
    return (false);
}
