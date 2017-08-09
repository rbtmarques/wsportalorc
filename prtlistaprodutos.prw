#Include 'totvs.ch'
#Include 'parmtype.ch'
#Include "RestFul.CH"

//-------------------------------------------------------------------
/*/{Protheus.doc} PRTLISTAPRODUTOS
Servi�o REST de lista de produtos para oportal de vendas

@author Felipe Toledo
@since 07/07/17
@type Method
/*/
//-------------------------------------------------------------------
WSRESTFUL PRTLISTAPRODUTOS DESCRIPTION "Servi�o REST de lista de produtos portal de vendas"

WSDATA CFILTROSQL As String OPTIONAL // String com filtro SQL
WSDATA NPAGE      As Integer OPTIONAL // Numero da pagina
WSDATA NLIMPAG    As Integer OPTIONAL // Numero Maximo de registros por pagina

WSMETHOD GET DESCRIPTION "Retorna todos os produtos disponiveis para o portal de vendas" WSSYNTAX "/PRTLISTAPRODUTOS "
 
END WSRESTFUL

//-------------------------------------------------------------------
/*/{Protheus.doc} GET
Processa as informa��es e retorna o json
@author Felipe Toledo
@since 07/07/17
@type Method
/*/
//-------------------------------------------------------------------
WSMETHOD GET WSRECEIVE CFILTROSQL, NPAGE, NLIMPAG WSSERVICE PRTLISTAPRODUTOS
Local oObjResp   := Nil
Local cJson      := ''
Local cAliasQry  := GetNextAlias()
Local cAliasTot  := ''
Local oObjResp   := PrtListaProdutos():New() // --> Objeto que ser� serializado
Local cFiltroSql := Self:CFILTROSQL
Local nPage      := Self:NPAGE
Local nRegPag    := Self:NLIMPAG // Registros por pagina
Local cPagDe     := ''
Local cPagAte    := ''
Local cWhere     := ''
Local cWhere2    := ''
Local nTotReg    := 0 // Total de Registros na consulta
Local nTotPag    := 0 // Total de Registros na Pagina
Local lRet       := .T.

// Converte string base64 para formato original
If !Empty(cFiltroSql)
	cFiltroSql := Decode64(cFiltroSql)
EndIf

//-------------------------------------------------------------
// Filtro na sele��o dos registros
//-------------------------------------------------------------
cWhere :="%"
If ! Empty(cFiltroSql)
	// Filtro SQL 
	cWhere += " AND " + cFiltroSql
EndIf
cWhere +="%"

// Controle de pagina��o
cWhere2 := "%"
If !Empty(nPage) .And. nPage > 0 .And. !Empty(nRegPag) .And. nRegPag > 0
	cPagDe  := AllTrim(Str((nPage * nRegPag) - (nRegPag-1)))
	cPagAte := Alltrim(Str(nPage * nRegPag))
	
	cWhere2 += " WHERE LINHA BETWEEN " + cPagDe + " AND " + cPagAte + " "
EndIf
cWhere2 += "%"

// Query para listar os produtos disponiveis para or�amento
BeginSql Alias cAliasQry
    SELECT B1_COD, B1_DESC
      FROM (
	SELECT ROW_NUMBER() OVER (ORDER BY B1_COD) AS LINHA, B1_COD, B1_DESC
	  FROM %Table:SB1% SB1
	 WHERE SB1.B1_FILIAL = %xFilial:SB1%
	   %Exp:cWhere%
	   AND SB1.B1_TIPO   = 'PA'
	   AND SB1.B1_MSBLQL <> '1'
	   AND SB1.%notDel% ) TRB
	   %Exp:cWhere2%
	 ORDER
	    BY B1_COD
EndSql

If (cAliasQry)->( ! Eof() )
	//Cria um objeto da classe produtos para fazer a serializa��o na fun��o FWJSONSerialize
	(cAliasQry)->(DbEval({||;
	nTotPag++,;
	oObjResp:Add( PrtItListaProdutos():New( B1_COD, B1_DESC ) );
	}))
EndIf

// Total de registros da pagina
oObjResp:SetRegPag(nTotPag)

(cAliasQry)->(DbCloseArea())

If lRet .And. (Empty(nPage) .Or. nPage <= 1)
	cAliasTot := GetNextAlias()
	// Query para listar os dados
	BeginSql Alias cAliasTot
		SELECT COUNT(*) TOTALREG
		  FROM %Table:SB1% SB1
		 WHERE SB1.B1_FILIAL = %xFilial:SB1%
		   %Exp:cWhere%
		   AND SB1.B1_TIPO   = 'PA'
		   AND SB1.B1_MSBLQL <> '1'
		   AND SB1.%notDel% 
	EndSql
	If (cAliasTot)->( ! Eof() )
		nTotReg := (cAliasTot)->TOTALREG
	EndIf
	
	(cAliasTot)->(DbCloseArea())
	
	oObjResp:SetTotReg(nTotReg)
EndIf

// --> Transforma o objeto de produtos em uma string json
cJson := FWJsonSerialize(oObjResp,.F.)

// define o tipo de retorno do m�todo
::SetContentType("application/json")

// --> Envia o JSON Gerado para a aplica��o Client
::SetResponse(cJson)

Return(lRet)