import Ex.Console as Console;
import System.Collections.ArrayList as ArrayList
import Dlinq.Linq as Dlinq;
import Microsoft.Data.SqlClient.SqlConnection as SqlConnection
import Microsoft.Data.SqlClient.SqlCommand as SqlCommand
import Ex.StatusConsole as StatusConsole

@conStr = "server=127.0.0.1,4036\\SQL2017;...";
@con = new clr.SqlConnection(@conStr);
@totalCount = 0; @count = 0; @current = clr.System.DateTime.Now;


clr.StatusConsole.Start("Start database importing ...");
clr.StatusConsole.Status("Start deleting PROD ...");
DeleteLastImportedProd();

// clr.Ex.Csv.ReadWithDelimiter(object file, string delimiter, object anonymousObjectTemplate)
clr.StatusConsole.Status("Start reading tsv file ...");
var lst = clr.Ex.Csv.Read("R:\\Prod.txt", dtoProd());
var e = lst.GetEnumerator(), log, listProds = new clr.ArrayList();

while(e.MoveNext()) {
	listProds.Add(e.Current);
	@totalCount = @totalCount + 1;
	if (@totalCount % 50 == 0) {
		clr.StatusConsole.Status("Total read: " & @totalCount );
	}
}

InsertDataIntoDatabase(listProds);

clr.StatusConsole.Stop();

mark("F75139", @totalCount & " rows are imported into MyStoreData2000.dbo.Prod. All done. You can close this window.");

=> null;

/*--------------------------------------
---------Database opertations---------*/

void DeleteLastImportedProd() {
	(clr.SqlConnection)@con..Open();
	StringBuilder sb;
	sb.AppendLine(@"
WITH NonExisting AS
(
	SELECT		p._prodid
	FROM		Product p
	WHERE		NOT EXISTS(
				SELECT	1
				FROM	Kindle k 
				WHERE	k._prodid = p._prodid
	)
)
INSERT	INTO Kindle (_prodid)
SELECT	n._prodid FROM NonExisting n;
SELECT	@@ROWCOUNT AS INSERTED
");
	string result = QuerySingleRow(sb.ToString(), "INSERTED");
	mark("2B91BD", result & " last time imported rows are inserted in the table kindle");

	result = QuerySingleRow("DELETE FROM Product;SELECT @@ROWCOUNT AS DELETED", "DELETED");
	mark("2B91BD", result & " rows are deleted in Product");
	
	(clr.SqlConnection)@con..Close();
}

void InsertDataIntoDatabase(data) {
	@totalCount = 0; @current = clr.System.DateTime.Now; @count = 0; 

	var dataToImport = (clr.ArrayList)data;
	(clr.SqlConnection)@con..Open();

	var e = dataToImport.GetEnumerator();
	while(e.MoveNext()) {
		@totalCount = @totalCount + 1;
		@count = @count + 1;

		InsertInDb(e.Current);
		
		if (@count > 10) {
			clr.StatusConsole.Status( @totalCount & ", "
					& e.Current.._prodid & " is processed. Speed: " 
					& (double)GetSpeed().ToString("0.00") & " /s"
			);
			@count = 0;
			@current = clr.System.DateTime.Now; // CHANGED: reset window only after logging
		}
	}

	(clr.SqlConnection)@con..Close();
	mark("2B91BD", @totalCount & " is processed");
}


void InsertInDb(item) {
	string sql = GenerateRowSql(item);
	RunSql(sql);
}

void RunSql(sql) {
	var com = new clr.SqlCommand(sql, (clr.SqlConnection)@con);
	var reader = clr.Ex.Sql.ExecuteReader(com);
	reader.Close();
}

func QuerySingleRow(sql, column) {
	var com = new clr.SqlCommand(sql, (clr.SqlConnection)@con);
	var reader = clr.Ex.Sql.ExecuteReader(com);
	bool isReady = reader.read();
	string result = reader.get_item(column.ToString());
	reader.Close();
	return result;
}

func GenerateRowSql(item) {
	StringBuilder sb;

	sb.Append("INSERT INTO Product (_prodid,_name,_category, ... ) ");
	sb.Append("VALUES (" & GenerateValue(item._prodid));
	sb.Append(", " & GenerateValue(item._name));
	sb.Append(");");
	/*...*/
	sb.Append("SELECT 1");
	
	=> sb.ToString();
}

func GenerateDateTime(field) {
	string result = "NULL";
	string datetime = "";
	if(field != null && !clr.System.String.IsNullOrEmpty(field.ToString())) {
		datetime = clr.System.DateTime.ParseExact(field.ToString(), "yyyy-MM-dd HH:mm:ss", null)
			.ToString("yyyy-MM-dd 00:00:00") ;
		result = "'" & datetime & "'" ;
	}
	=> result; 
}

func GenerateValue(field) {
	string result = "NULL";
	if(field != null && !clr.System.String.IsNullOrEmpty(field.ToString())) {
		result = "'" & field.ToString().Replace("'", "''").Trim() & "'" ;
	}
	=> result; 
}

func GetSpeed() {
	double seconds = now.Subtract((clr.System.DateTime)@current).TotalSeconds;
	if (seconds <= 0.001) { seconds = 0.001; }
	=> (double)@count / seconds;
}

/*---------End of database opertations---------
----------------------------------------------*/

func dtoProd() {
	=> new {
		prodid: "",
		name: "",
		/* ... */
		brand: "",
		fields: ""
	};
}

func dtoMessage() {
	=> new {
		accountId:"", contractId:"", userId:"s", 
		time: ""
	}
}

func select(arr, prop) { => clr.Dlinq.Select(arr, prop.ToString()); }
func orderby(arr, by) { => clr.Dlinq.OrderBy(arr, by.ToString() ); }
func where(arr, p) { => clr.Dlinq.Where(arr, p.ToString() ) ; }
func any(arr, p) { => clr.Dlinq.Any(arr, "it.ToString() == \"" & p & "\"" ) ; }

// mark("C21515", "Red" ) 
// mark("2B91AF", "Blue" ) 
void mark(color, content) {
    clr.Ex.Console.Markup("[#" & color & "]"
        & content.ReplStr("[", "").ReplStr("]", "").ReplStr("[/]", "")
        & "[/]\r\n"
    );
}

