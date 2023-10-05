
export type RegisterProps = {
    email: string;
    setEmail: (email: string) => void,
    login: () => void;
} 

export function Register({ login, setEmail, email }: RegisterProps) {

    return (
        <div className="text-center py-24">
            <div>
                <label className="mb-4">Insert your e-mail to start playing</label>
                <input type="text"
                    value={email}
                    className="w-[350px] block mx-auto border-black border rounded-lg px-3 mt-3 py-2"
                    placeholder="Type your e-mail"
                    onChange={(e) => {
                        setEmail(e.target.value)
                    }}
                />
            </div >

            <div className='pt-12'>
                <button className="disabled:opacity-30"
                    disabled={!email || !email.includes('@')}
                    onClick={login}
                >Start Playing</button>
            </div>
        </div>
    )
}
