unit kubo.rest.client;

interface

uses
  system.sysutils,
  system.classes,
  system.math,
  system.variants,
  system.json,
  system.netencoding,
  system.generics.collections,
  fmx.dialogs,
  rest.client,
  rest.types,
  rest.json,
  kubo.rest.client.interfaces,
  kubo.rest.client.types,
  kubo.rest.client.utils,
  kubo.rest.client.json;

type

  tkuboRestClient<t: class, constructor> = class(tinterfacedobject, ikuboRestClient<t>)
  private
    {private declarations}
    frequest: ikuboRequest<t>;
    fcontenttype: string;
    fauthentication: ikuboAuthentication<t>;
    fparams: ikuboParams<t>;

    frest_client_: trestclient;
    frest_request_: trestrequest;
    frest_response_: trestresponse;

    frest_request_json_body_itens: tjsonobject;

    function doprepare: boolean;
    function dorequest(const prest_eequest_method: trestrequestmethod): string;
  public
    {public declarations}
    constructor create(const puri: string = ''; const presource: string = '');
    destructor destroy; override;

    class function new(const pbase_url: string = ''; const presource: string = ''): ikuboRestClient<t>;

    function request: ikuboRequest<t>;
    function contenttype(const pcontenttype: string): ikuboRestClient<t>;
    function authentication(ptype: tkuboAuthenticationType = taNone): ikuboAuthentication<t>;
    function params: ikuboParams<t>;

    function get: string; overload;
    function get(var akubo_object_array: ikuboJsonArray<t>): ikuboRestClient<t>; overload;
    function get(var akubo_object: ikuboJsonObject<t>): ikuboRestClient<t>; overload;

    function post: ikuboRestClient<t>; overload;
    function put: ikuboRestClient<t>; overload;
    function delete: boolean;
  end;

implementation

{ tkuboRestClient<t> }

uses
  kubo.json.objects,
  kubo.rest.client.request,
  kubo.rest.client.authenticatoin,
  kubo.rest.client.params;

function tkuboRestClient<t>.authentication(ptype: tkuboAuthenticationType = taNone): ikuboAuthentication<t>;
begin
  result := fauthentication.types(ptype);
end;

function tkuboRestClient<t>.contenttype(const pcontenttype: string): ikuboRestClient<t>;
begin
  result := self;
  fcontenttype := pcontenttype;
end;

constructor tkuboRestClient<t>.create(const puri: string = ''; const presource: string = '');
begin
  frequest := tkuboRequest<t>.new(self);

  //set default values rest json client application
    frequest.uri(puri);
    frequest.resource(presource);
    frequest.accept('application/json, text/plain; q=0.9, text/html;q=0.8');
    frequest.charset('utf-8, *;q=0.8');

  //contenttype
    fcontenttype := 'application/json';

  //authentication
    fauthentication := tkuboAuthentication<t>.create(self);

  //params
    fparams := tkuboParams<t>.create(self);

  frest_client_ := nil;
  frest_request_:= nil;
  frest_response_:= nil;
end;

function tkuboRestClient<t>.delete: boolean;
begin
  result := true;
  self.dorequest(trestrequestmethod.rmput);
end;

destructor tkuboRestClient<t>.destroy;
begin
  if frest_response_ <> nil then
    freeandnil(frest_response_);

  if frest_request_ <> nil then
    freeandnil(frest_request_);

  if frest_client_ <> nil then
    freeandnil(frest_client_);

  if frest_request_json_body_itens <> nil then
    freeandnil(frest_request_json_body_itens);

  inherited;
end;

function tkuboRestClient<t>.doprepare: boolean;
var
  lint_count_: integer;
  li_str_strem_body: tstringstream;
begin
  result := false;
  li_str_strem_body := nil;

  try
    case fauthentication.types of
    taBasic: params.add('Authorization', '', 'Basic ' +  tnetencoding.base64.encode(fauthentication.login + ':' + fauthentication.password), kpkHTTPHeader);
    taBearer: params.add('Authorization', '', 'Bearer ' + fauthentication.token, kpkHTTPHeader);
    end;


    for lint_count_ := 0 to params.count - 1 do
      case params.items(lint_count_).kind of
      kpkHTTPHeader:
        begin
          if trim(vartostr(params.items(lint_count_).value)) = '' then
            exit;
          frest_client_.addparameter(params.items(lint_count_).name, vartostr(params.items(lint_count_).value), pkHTTPHEADER);
        end;
      kpkURLSegment:
        begin
          if trim(vartostr(params.items(lint_count_).value)) = '' then
            exit;

          frest_request_.resource := frest_request_.resource +
                                     iif(
                                          params.items(lint_count_).resource.trim <> '',
                                          iif(
                                              pos('/' + params.items(lint_count_).resource.trim, frest_request_.resource) > 0,
                                              '',
                                              '/'  + params.items(lint_count_).resource.trim
                                             ),
                                          iif(
                                             vartostr(params.items(lint_count_).value).trim = '',
                                              params.items(lint_count_).name,
                                              iif(
                                                  pos('?', frest_request_.resource) > 0,
                                                  '',
                                                  '?'
                                                  )
                                              +
                                              iif(
                                                  pos('}', frest_request_.resource) > 0,
                                                  '&',
                                                  ''
                                                 )
                                              +
                                              params.items(lint_count_).name + '=' + '{' +  params.items(lint_count_).name + '}'
                                             )
                                          );

          frest_request_.addparameter(params.items(lint_count_).name, vartostr(params.items(lint_count_).value), pkURLSEGMENT);
        end;
      kpkGetPost:
        begin
          if vartostr(params.items(lint_count_).value).trim <> '' then
            frest_request_.addparameter(params.items(lint_count_).name, vartostr(params.items(lint_count_).value), pkGETorPOST);
        end;
      kpkRequestBody:
        begin
          if trim(vartostr(params.items(lint_count_).value)) = '' then
            exit;

          {cria o json body se ainda n�o estiver criado}
            if frest_request_json_body_itens = nil then
              frest_request_json_body_itens := system.json.tjsonobject.create;

          {verifica se o parametro passado ja n�o � oum json string}
            var li_rest_request_json_body_iten: tjsonobject;
            try
              li_rest_request_json_body_iten := tjsonobject.parsejsonvalue(
                                                              tencoding.ascii.getbytes(vartostr(params.items(lint_count_).value))
                                                              , 0) as tjsonobject;

            except
              if li_rest_request_json_body_iten <> nil then
                freeandnil(li_rest_request_json_body_iten);
            end;

          if params.items(lint_count_).name.trim <> '' then
          begin
            {se a variavel "li_rest_request_json_body_iten" for difernete de nil quer diser que o valor passado
            no parametro era um json string assim deve adicionar o json item direto, se n�o adiciona o valor}
            if li_rest_request_json_body_iten  <> nil then
              frest_request_json_body_itens.addpair(params.items(lint_count_).name, li_rest_request_json_body_iten)
            else
              frest_request_json_body_itens.addpair(params.items(lint_count_).name, params.items(lint_count_).value);

            {cria o body data para adicionar o valor no bory request}
             li_str_strem_body := tstringstream.create(
                                            stringreplace(unquoted(frest_request_json_body_itens.tojson), '\', '', [rfReplaceAll]),
                                            tencoding.utf8);
          end
          else
            {cria o body data para adicionar o valor no bory request}
            li_str_strem_body := tstringstream.create(
                                            stringreplace(unquoted(li_rest_request_json_body_iten.tojson), '\', '', [rfReplaceAll]),
                                            tencoding.utf8);


          if li_rest_request_json_body_iten <> nil then
            freeandnil(li_rest_request_json_body_iten);

          {adiconar o bodydata no bory request}
            frest_request_.clearbody;
            frest_request_.addbody(li_str_strem_body, trestcontenttype.ctapplication_json);
            freeandnil(li_str_strem_body);
        end;
      end;

    result := true;
  finally

  end;
end;

function tkuboRestClient<t>.dorequest(const prest_eequest_method: trestrequestmethod): string;
var
  lint_count_: integer;
begin
  result := '';
  frest_client_ := nil;
  frest_response_ := nil;
  frest_request_ := nil;

  try
    try
      frest_client_ := trestclient.create(frequest.uri);
      frest_client_.accept := frequest.accept;
      frest_client_.acceptcharset := frequest.charset;

      frest_response_ := trestresponse.create(frest_client_);
      frest_response_.contenttype   := fcontenttype;

      frest_request_ := trestrequest.create(frest_client_);
      frest_request_.client := frest_client_;
      frest_request_.response := frest_response_;

      frest_request_.method := prest_eequest_method;
      frest_request_.resource := frequest.resource;

      if doprepare then
      begin
        try
          frest_request_.execute;
        except
          on e: exception do
          begin
            if pos('HTTP/1.1 500', e.message) > 0 then
              result := frest_response_.jsontext
            else
              raise;
          end
        end;

        if result.trim = '' then
          result := frest_response_.jsontext;
      end;
    except
      on E: Exception do
        raise;
    end;
  finally
    frest_client_.disconnect;

    if frest_response_ <> nil then
      freeandnil(frest_response_);

    if frest_request_ <> nil then
      freeandnil(frest_request_);

    if frest_client_ <> nil then
      freeandnil(frest_client_);
  end;
end;

function tkuboRestClient<t>.get(var akubo_object: ikuboJsonObject<t>): ikuboRestClient<t>;
var
  lstr_response: string;
begin
  result := self;
  lstr_response := self.get;
  if lstr_response.trim <> '' then
  begin
    if akubo_object = nil then
      akubo_object := tkuboJsonObject<t>.create;

    akubo_object.asjson := lstr_response;
  end;
end;

function tkuboRestClient<T>.get(var akubo_object_array: ikuboJsonArray<T>): ikuboRestClient<t>;
var
  lstr_response: string;
begin
  Result := Self;

  lstr_response := Self.get;
  if lstr_response.trim <> '' then
  begin
    if akubo_object_array = nil then
      akubo_object_array := tkuboJsonArray<t>.create;

    akubo_object_array.asjson := lstr_response;
  end;
end;

function tkuboRestClient<t>.get: string;
begin
  result := self.dorequest(trestrequestmethod.rmget);
end;

class function tkuboRestClient<t>.new(const pbase_url: string; const presource: string): ikuboRestClient<t>;
begin
  result := self.create(pbase_url, presource);
end;

function tkuboRestClient<t>.params: ikuboParams<t>;
begin
  result := fparams;
end;

function tkuboRestClient<t>.post: ikuboRestClient<t>;
begin
  result := self;
  self.dorequest(trestrequestmethod.rmpost);
end;

function tkuboRestClient<t>.put: ikuboRestClient<t>;
begin
  result := self;
  self.dorequest(trestrequestmethod.rmput);
end;

function tkuboRestClient<t>.request: ikuboRequest<t>;
begin
  result := frequest;
end;

end.
