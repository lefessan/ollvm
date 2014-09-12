module Type = struct

  open Ast

  type typ = Ast.typ

  let i1 = TYPE_I 1
  let i32 = TYPE_I 32
  let half = TYPE_Half
  let float = TYPE_Float
  let double = TYPE_Double
  let pointer t = TYPE_Pointer t
  let vector n t = TYPE_Vector (n, t)
  let label = TYPE_Label
  let void = TYPE_Void
  let array n t = TYPE_Array (n, t)
  let structure s = TYPE_Struct s

end

module Value = struct

  type typ = Type.typ

  type tvalue = typ * Ast.value

  let i1 n = (Type.i1, Ast.VALUE_Integer n)

  let i32 n = (Type.i32, Ast.VALUE_Integer n)

  let half f = (Type.half, Ast.VALUE_Float f)

  let float f = (Type.float, Ast.VALUE_Float f)

  let double f = (Type.double, Ast.VALUE_Float f)

  let vector l =
    (Type.vector (List.length l) (fst (List.hd l)), Ast.VALUE_Vector l)

  let array l =
    (Type.array (List.length l) (fst (List.hd l)), Ast.VALUE_Array l)

  let structure l =
    (Type.structure (List.map fst l),
     Ast.VALUE_Struct l)

  let ident (t, Ast.VALUE_Ident id) = (t, id)

end

module Instr = struct


  type typ = Type.typ

  type tvalue = Value.tvalue

  type tinstr = typ * Ast.instr

  let ident = Value.ident

  let call ((t, _) as fn) args =
    (t, Ast.INSTR_Call (ident fn, args))

  let phi value_label =
    let t = List.hd value_label |> fst |> fst in
    let value_label =
      List.map (fun (v, i) -> (snd v, snd (ident i))) value_label in
    (t, Ast.INSTR_Phi (t, value_label))

  let select tcond (t, v1) tv2 =
    (t, Ast.INSTR_Select (tcond, (t, v1), tv2))

  let alloca ?(nb=None) ?(align=None) t =
    (Type.pointer t, Ast.INSTR_Alloca (t, nb, align))

  let load ?(volatile=false) ?(align=None) (ptr_t, value) =
    let [@ocaml.warning "-8"] Ast.TYPE_Pointer t = ptr_t in
    (t, Ast.INSTR_Load (volatile, (ptr_t, value), align))

  let store ?(volatile=false)? (align=None) value pointer =
    (Type.void, Ast.INSTR_Store (volatile, value, ident pointer, align))

  type bin_sig = tvalue -> tvalue -> tinstr

  let icmp cmp (t, op1) (_, op2) =
    (Type.i1, Ast.INSTR_ICmp (cmp, t, op1, op2))

  let eq = icmp Ast.Eq let ne = icmp Ast.Ne
  let ugt = icmp Ast.Ugt let uge = icmp Ast.Uge
  let ult = icmp Ast.Ult let ule = icmp Ast.Ule
  let sgt = icmp Ast.Sgt let sge = icmp Ast.Sge
  let slt = icmp Ast.Slt let sle = icmp Ast.Sle

  let fcmp cmp (t, op1) (_, op2) =
    (Type.i1, Ast.INSTR_FCmp (cmp, t, op1, op2))

  let ffalse = fcmp Ast.False let foeq = fcmp Ast.Oeq
  let fogt = fcmp Ast.Ogt let foge = fcmp Ast.Oge
  let folt = fcmp Ast.Olt let fole = fcmp Ast.Ole
  let fone = fcmp Ast.One let ord = fcmp Ast.Ord
  let fueq = fcmp Ast.Ueq let fugt = fcmp Ast.Ugt
  let fuge = fcmp Ast.Uge let fult = fcmp Ast.Ult
  let fule = fcmp Ast.Ule let fune = fcmp Ast.Une
  let funo = fcmp Ast.Uno let ftrue = fcmp Ast.True

  type nsw_nuw_ibinop_sig = ?nsw:bool -> ?nuw:bool -> bin_sig
  type exact_ibinop_sig = ?exact:bool -> bin_sig

  let ibinop b (t, op1) (_, op2) =
    (t, Ast.INSTR_IBinop (b, t, op1, op2))

  let add ?(nsw=false) ?(nuw=false) = ibinop (Ast.Add (nsw, nuw))
  let sub ?(nsw=false) ?(nuw=false) = ibinop (Ast.Sub (nsw, nuw))
  let mul ?(nsw=false) ?(nuw=false) = ibinop (Ast.Mul (nsw, nuw))
  let udiv ?(exact=false) = ibinop (Ast.UDiv exact)
  let sdiv ?(exact=false) = ibinop (Ast.SDiv exact)
  let urem = ibinop Ast.URem
  let srem = ibinop Ast.SRem
  let shl ?(nsw=false) ?(nuw=false) = ibinop (Ast.Shl (nsw, nuw))
  let lshr ?(exact=false) = ibinop (Ast.LShr exact)
  let ashr ?(exact=false) = ibinop (Ast.AShr exact)
  let and_ = ibinop Ast.And
  let or_ = ibinop Ast.Or
  let xor = ibinop Ast.Xor

  type fbinop_sig = ?flags:Ast.fast_math list -> bin_sig

  let fbinop b ?(flags=[])  (t, op1) (_, op2) =
    (t, Ast.INSTR_FBinop (b, flags, t, op1, op2))

  let fadd = fbinop Ast.FAdd
  let fsub = fbinop Ast.FSub
  let fmul = fbinop Ast.FMul
  let fdiv = fbinop Ast.FDiv
  let frem = fbinop Ast.FRem

  let extractelement vec idx =
    let [@ocaml.warning "-8"] (Ast.TYPE_Vector (n, t), _) = vec in
    (t, Ast.INSTR_ExtractElement (vec, idx))

  let insertelement vec el idx =
    (fst vec, Ast.INSTR_InsertElement (vec, el, idx))

  let shufflevector v1 v2 vmask =
    let (vec_t, _) = v1 in
    (vec_t, Ast.INSTR_ShuffleVector (v1, v2, vmask))

  type convert_sig = tvalue -> typ -> tinstr

  let convert op (t, v) t' = (t', Ast.INSTR_Conversion(op, t, v, t'))

  let trunc = convert Ast.Trunc let zext = convert Ast.Zext
  let sext = convert Ast.Sext let fptrunc = convert Ast.Fptrunc
  let fpext = convert Ast.Fpext let fptoui = convert Ast.Fptoui
  let fptosi = convert Ast.Fptosi let uitofp = convert Ast.Uitofp
  let sitofp = convert Ast.Sitofp

  let extractvalue agg idx =
    (fst agg, Ast.INSTR_ExtractValue (agg, idx))

  let insertvalue agg el idx =
    (fst agg, Ast.INSTR_InsertValue (agg, el, idx))

  let br cond (t, Ast.VALUE_Ident then_) (t', Ast.VALUE_Ident else_) =
    Ast.INSTR_Br (cond, (t, then_), (t', else_))

  let br1 (t, Ast.VALUE_Ident branch) =
    Ast.INSTR_Br_1 (t, branch)

  let switch sw default cases =
    let cases = List.map (fun (v, i) -> (v, ident i)) cases in
    Ast.INSTR_Switch (sw, ident default, cases)

  let ret tvalue = Ast.INSTR_Ret tvalue

  let ret_void = Ast.INSTR_Ret_void

  let assign id (_, expr) =
    let (_, id) = ident id in
    Ast.INSTR_Assign (id, expr)

  let ( <-- ) tid texpr = assign tid texpr

  let ignore (_, expr) = expr

end

module Block = struct

  type block = Ast.ident * (Ast.instr list)

  type typ = Type.typ

  type tvalue = Value.tvalue

  let declare fn args_typ =
    let (t, id) = Value.ident fn in
    let open Ast in
    { dc_ret_typ = (t, []);
      dc_name = id;
      dc_args = List.map (fun x -> (x, [])) args_typ }

  let define fn args (instrs : block list) =
    let args = List.map Value.ident args in
    let open Ast in
    let extract_name = function
      | Ast.ID_Local (Ast.ID_FORMAT_Named, s) -> s
      | _ -> assert false in

    let blocks = List.map (fun (id, instrs) -> (extract_name id, instrs)) instrs

    in
    let proto = declare fn (List.map fst args) in

    { df_prototype = proto;
      df_args = List.map snd args;
      df_instrs = blocks;
      df_linkage =  None;
      df_visibility = None;
      df_dll_storage = None;
      df_cconv = None;
      df_attrs = [];
      df_section = None;
      df_align = None;
      df_gc = None;
    }

  let block  id instrs =
    let (_, id) = Value.ident id in (id, instrs)

end

module Env = struct

  type t = { unnamed_counter : int;
             named_counter : (string * int) list }

  let empty = { unnamed_counter = 0 ;
                named_counter = [] }

  (* FIXME: Use better structure than list *)
  let local env t name =
    let (env, (format, name)) = match name with
      | "" ->
         let i = env.unnamed_counter in
         ({ env with unnamed_counter = i + 1 ; },
          (Ast.ID_FORMAT_Named, string_of_int i))
      | name -> try let i = List.assoc name env.named_counter in
                    ({env with named_counter = (name, i + 1) :: env.named_counter},
                     (Ast.ID_FORMAT_Unnamed, name ^ string_of_int i))
                with Not_found -> ({env with named_counter = (name, 0) :: env.named_counter},
                                   (Ast.ID_FORMAT_Named, name))
    in
    (env, (t, Ast.VALUE_Ident (Ast.ID_Local (format, name))))

end

module Module = struct

  (** NOTE: declaration and definitions are kept in reverse order. **)

  type t = {
    m_module: Ast.modul;
    m_env: Env.t;
  }

  let data_layout layout = Ast.TLE_Datalayout layout

  let target_triple arch vendor os =
    Ast.TLE_Target (arch ^ "-" ^ vendor ^ "-" ^ os)

  let local m t name =
    let (env, var) = Env.local m.m_env t name in
    ({m with m_env = env}, var)

  let global m t name =
    let ident = Ast.ID_Global (Ast.ID_FORMAT_Named, name) in
    let var = (t, Ast.VALUE_Ident ident) in
    (m, var)

  let lookup_declaration m name =
    List.assoc name m.m_module.m_declarations

  let lookup_definition m name =
    List.assoc name m.m_module.m_definitions

  let declaration m dc name =
    { m with m_module = { m.m_module with
                          m_declarations = (name, dc)
                                           :: m.m_module.m_declarations } }

  let definition m df name =
    let { Ast.df_prototype = dc; _; } = df in
    { m with m_module = { m.m_module with
                          m_declarations = (name, dc)
                                           :: m.m_module.m_declarations ;
                          m_definitions = (name, df)
                                          :: m.m_module.m_definitions } }

end